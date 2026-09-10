<?php

namespace App\Services\Reading;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class OpenRouterClient
{
    /**
     * @param array<string, mixed> $input
     * @return array{narrative:string,disclaimer:string,line_situations:array<int,array<string,mixed>>}
     */
    public function generateReading(array $input, string $correlationId): array
    {
        $snapshot = json_encode($input, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: '{}';

        $prompt = <<<PROMPT
You are a concise palm-reading assistant.
Create one complete, grounded, probabilistic, non-mystical palm reading in friendly professional English.
Do not use markdown or bullet points.

Return ONLY valid JSON matching the requested schema.

Rules:
1) Base every field on the provided palm findings and line signals.
2) Do not mention image quality, confidence scores, camera issues, or retake advice.
3) Do not use percentages and do not claim certainty.
4) Narrative must be one paragraph of 120-200 words.
5) Make the narrative feel personally accurate with 3-5 concrete traits, including strengths and blind spots.
6) Include 1-2 “this often shows up as…” examples, preferably involving work and relationships.
7) Include current life direction, likely near-term tendencies, practical improvements, and a motivating close.
8) Disclaimer must clearly say this is reflective guidance, not a guaranteed prediction.
9) Return exactly five line_situations entries with keys life, head, heart, fate, and sun.
10) Keep each line field to one short practical English sentence of no more than 18 words.
11) For each line, include a current situation, a probabilistic near-future direction, and a concrete self-improvement suggestion.
12) Keep the tone supportive and professional. Avoid harsh or overly negative framing.

Input snapshot:
{$snapshot}
PROMPT;

        $decoded = $this->requestJson(
            prompt: $prompt,
            schema: $this->readingSchema(),
            schemaName: 'palm_reading',
            correlationId: $correlationId,
            minTokens: 900
        );

        $narrative = trim((string) ($decoded['narrative'] ?? ''));
        $disclaimer = trim((string) ($decoded['disclaimer'] ?? ''));
        $lineSituations = $decoded['line_situations'] ?? null;

        if ($narrative === '' || $disclaimer === '' || ! is_array($lineSituations)) {
            throw new RuntimeException('OpenRouter reading payload is incomplete.');
        }

        return [
            'narrative' => $narrative,
            'disclaimer' => $disclaimer,
            'line_situations' => $lineSituations,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function readingSchema(): array
    {
        return [
            'type' => 'object',
            'required' => ['narrative', 'disclaimer', 'line_situations'],
            'additionalProperties' => false,
            'properties' => [
                'narrative' => ['type' => 'string'],
                'disclaimer' => ['type' => 'string'],
                'line_situations' => [
                    'type' => 'array',
                    'minItems' => 5,
                    'maxItems' => 5,
                    'items' => [
                        'type' => 'object',
                        'required' => ['key', 'title', 'situation', 'prediction', 'suggestion'],
                        'additionalProperties' => false,
                        'properties' => [
                            'key' => [
                                'type' => 'string',
                                'enum' => ['life', 'head', 'heart', 'fate', 'sun'],
                            ],
                            'title' => ['type' => 'string'],
                            'situation' => ['type' => 'string'],
                            'prediction' => ['type' => 'string'],
                            'suggestion' => ['type' => 'string'],
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $schema
     * @return array<string, mixed>
     */
    private function requestJson(
        string $prompt,
        array $schema,
        string $schemaName,
        string $correlationId,
        int $minTokens
    ): array {
        $apiKey = trim((string) config('palm.openrouter_api_key', ''));
        if ($apiKey === '') {
            throw new RuntimeException('OpenRouter API key is not configured.');
        }

        $baseUrl = rtrim((string) config('palm.openrouter_base_url', 'https://openrouter.ai/api/v1'), '/');
        $model = trim((string) config('palm.openrouter_model', 'openai/gpt-4o'));
        if ($model === '') {
            $model = 'openai/gpt-4o';
        }

        $timeout = max(10, (int) config('palm.llm_timeout_seconds', 60));
        $temperature = (float) config('palm.llm_temperature', 0);
        $maxTokens = max($minTokens, (int) config('palm.llm_num_predict', 900));

        $payload = [
            'model' => $model,
            'messages' => [
                [
                    'role' => 'user',
                    'content' => $prompt,
                ],
            ],
            'stream' => false,
            'temperature' => $temperature,
            'max_tokens' => $maxTokens,
            'seed' => (int) config('palm.llm_seed', 42),
            'response_format' => [
                'type' => 'json_schema',
                'json_schema' => [
                    'name' => $schemaName,
                    'strict' => true,
                    'schema' => $schema,
                ],
            ],
        ];

        try {
            $response = Http::timeout($timeout)
                ->acceptJson()
                ->withToken($apiKey)
                ->withHeaders(['X-Correlation-Id' => $correlationId])
                ->post($baseUrl.'/chat/completions', $payload);
        } catch (ConnectionException $exception) {
            throw new RuntimeException('OpenRouter connection failed: '.$exception->getMessage());
        }

        if (! $response->successful()) {
            throw new RuntimeException('OpenRouter failed with status '.$response->status());
        }

        $body = $response->json();
        $content = is_array($body)
            ? ($body['choices'][0]['message']['content'] ?? null)
            : null;

        if (! is_string($content) || trim($content) === '') {
            throw new RuntimeException('OpenRouter payload missing message content.');
        }

        $jsonText = trim($content);
        $decoded = json_decode($jsonText, true);
        if (! is_array($decoded)) {
            $candidate = $this->extractJsonObject($jsonText);
            if ($candidate !== null) {
                $decoded = json_decode($candidate, true);
            }
        }

        if (! is_array($decoded)) {
            throw new RuntimeException('OpenRouter produced invalid JSON.');
        }

        return $decoded;
    }

    private function extractJsonObject(string $text): ?string
    {
        $start = strpos($text, '{');
        $end = strrpos($text, '}');

        if ($start === false || $end === false || $end <= $start) {
            return null;
        }

        return substr($text, $start, $end - $start + 1);
    }
}
