<?php

namespace App\Services\Reading;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class OllamaClient
{
    /**
     * @param array<string, mixed> $input
     * @return array{narrative:string,disclaimer:string}
     */
    public function generateNarrativeAndDisclaimer(array $input, string $correlationId): array
    {
        $snapshot = json_encode($input, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        $prompt = <<<PROMPT
You are a concise palm-reading assistant.
Write grounded, probabilistic, non-mystical text in friendly professional tone.
Do not use markdown or bullet points.

Output ONLY valid JSON:
{
  "narrative": "string",
  "disclaimer": "string"
}

Rules:
1) Base the narrative on provided palm findings and line signals.
2) Do not mention image quality, confidence scores, camera issues, or retake advice.
3) Do not use percentages and do not claim certainty.
4) Narrative must be one paragraph, 120-200 words.
5) Make it feel personally accurate by describing character and day-to-day tendencies inferred from the findings:
   - include 3-5 concrete traits (strengths + blind spots)
   - include 1-2 “this often shows up as…” examples (work and relationships are best)
   - keep it supportive and motivating, never harsh
6) Narrative must include current life direction, likely near-term tendencies, practical improvements, and a motivating close.
6) Disclaimer must clearly say this is reflective guidance, not guaranteed prediction.
7) Use English only.
8) Keep sentences compact: avoid long clauses and keep wording simple.

Input snapshot:
{$snapshot}
PROMPT;

        $schema = [
            'type' => 'object',
            'required' => ['narrative', 'disclaimer'],
            'additionalProperties' => false,
            'properties' => [
                'narrative' => ['type' => 'string'],
                'disclaimer' => ['type' => 'string'],
            ],
        ];

        $decoded = $this->requestJson(
            prompt: $prompt,
            schema: $schema,
            correlationId: $correlationId,
            seedHash: (string) ($input['signature_hash'] ?? '0'),
            minPredict: 260
        );

        $narrative = trim((string) ($decoded['narrative'] ?? ''));
        $disclaimer = trim((string) ($decoded['disclaimer'] ?? ''));

        if ($narrative === '' || $disclaimer === '') {
            throw new RuntimeException('Ollama narrative payload missing required fields.');
        }

        return [
            'narrative' => $narrative,
            'disclaimer' => $disclaimer,
        ];
    }

    /**
     * @param array<string, mixed> $input
     * @return array{line_situations: array<int, array<string, mixed>>}
     */
    public function generateLineSituations(array $input, string $correlationId): array
    {
        $snapshot = json_encode($input, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        $prompt = <<<PROMPT
You are a concise palm-reading assistant.
Create five line-by-line insights from palm findings.
Do not use markdown or bullet points.

Output ONLY valid JSON:
{
  "line_situations": [
    {
      "key": "life|head|heart|fate|sun",
      "title": "string",
      "situation": "string",
      "prediction": "string",
      "suggestion": "string"
    }
  ]
}

Rules:
1) Return exactly five entries, one for each key: life, head, heart, fate, sun.
2) Base content on provided findings and signals.
3) Do not mention image quality, confidence scores, camera issues, or retake advice.
4) Do not use percentages and do not claim certainty.
5) Keep each field to one short practical sentence (max 18 words each):
   - situation: current life context indicated by the line.
   - prediction: likely direction in near future (probabilistic wording).
   - suggestion: concrete self-improvement action.
6) Tone must be supportive and professional. Avoid overly negative framing. Name a strength even when describing a challenge.
7) Use English only.
8) Avoid long clauses, lists, and semicolons. Use simple punctuation.

Input snapshot:
{$snapshot}
PROMPT;

        $schema = [
            'type' => 'object',
            'required' => ['line_situations'],
            'additionalProperties' => false,
            'properties' => [
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

        $decoded = $this->requestJson(
            prompt: $prompt,
            schema: $schema,
            correlationId: $correlationId,
            seedHash: (string) ($input['signature_hash'] ?? '0'),
            minPredict: 650
        );

        if (! is_array($decoded['line_situations'] ?? null)) {
            throw new RuntimeException('Ollama line_situations payload missing required fields.');
        }

        return [
            'line_situations' => $decoded['line_situations'],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function rewriteReadingInEnglish(array $payload, string $correlationId, string $seedHash): array
    {
        $snapshot = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        $prompt = <<<PROMPT
Rewrite the provided JSON values into clear English only.
Preserve the exact JSON structure and keys.
Do not add or remove fields.
Do not output anything except valid JSON.
All text values must be natural English sentences only. Remove all non-English words.
Keep the text concise:
- narrative: one paragraph, 120-200 words
- disclaimer: one sentence, max 30 words
- each line field (title/situation/prediction/suggestion): one sentence, max 18 words

Input JSON:
{$snapshot}
PROMPT;

        $schema = [
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

        return $this->requestJson(
            prompt: $prompt,
            schema: $schema,
            correlationId: $correlationId,
            seedHash: $seedHash,
            minPredict: 700,
            modelOverride: (string) config('palm.llm_english_model', 'llama3.2:1b')
        );
    }

    /**
     * @param array<string, mixed> $schema
     * @return array<string, mixed>
     */
    private function requestJson(
        string $prompt,
        array $schema,
        string $correlationId,
        string $seedHash,
        int $minPredict,
        ?string $modelOverride = null
    ): array {
        $baseUrl = rtrim((string) config('palm.llm_base_url', 'http://ollama:11434'), '/');
        $model = trim((string) ($modelOverride ?: config('palm.llm_model', 'llama3.2:1b')));
        if ($model === '') {
            $model = 'llama3.2:1b';
        }
        $timeout = max(10, (int) config('palm.llm_timeout_seconds', 60));
        $temperature = (float) config('palm.llm_temperature', 0);
        $numPredict = max($minPredict, (int) config('palm.llm_num_predict', 420));

        $payload = [
            'model' => $model,
            'stream' => false,
            'format' => $schema,
            'prompt' => $prompt,
            'options' => [
                'temperature' => $temperature,
                'top_p' => 1,
                'seed' => $this->seedFromHash($seedHash),
                'num_predict' => $numPredict,
            ],
        ];

        try {
            $response = Http::timeout($timeout)
                ->acceptJson()
                ->withHeaders(['X-Correlation-Id' => $correlationId])
                ->post($baseUrl.'/api/generate', $payload);
        } catch (ConnectionException $exception) {
            throw new RuntimeException('Ollama connection failed: '.$exception->getMessage());
        }

        if (! $response->successful()) {
            throw new RuntimeException('Ollama failed with status '.$response->status());
        }

        $body = $response->json();
        if (! is_array($body) || ! isset($body['response'])) {
            throw new RuntimeException('Ollama payload missing response.');
        }

        $jsonText = trim((string) $body['response']);
        $decoded = json_decode($jsonText, true);
        if (! is_array($decoded)) {
            $candidate = $this->extractJsonObject($jsonText);
            if ($candidate !== null) {
                $decoded = json_decode($candidate, true);
            }
        }

        if (! is_array($decoded)) {
            $snippet = mb_substr($jsonText, 0, 280);
            throw new RuntimeException('Ollama produced invalid JSON. Snippet: '.$snippet);
        }

        return $decoded;
    }

    private function seedFromHash(string $hash): int
    {
        return (int) config('palm.llm_seed', 42);
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
