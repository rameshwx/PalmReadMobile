<?php

namespace App\Services\Reading;

use Illuminate\Support\Facades\Log;
use Throwable;

class LlmReadingGenerator
{
    /**
     * @var array<int, string>
     */
    private const LINE_KEYS = ['life', 'head', 'heart', 'fate', 'sun'];

    /**
     * @var array<string, string>
     */
    private const LINE_TITLES = [
        'life' => 'Life line',
        'head' => 'Head line',
        'heart' => 'Heart line',
        'fate' => 'Fate line',
        'sun' => 'Sun (Apollo) line',
    ];

    public function __construct(private readonly OpenRouterClient $openRouterClient)
    {
    }

    /**
     * @param array<string, mixed> $baseResultJson
     * @param array<int, array<string, mixed>> $lineSignals
     * @param array<string, mixed> $quantized
     * @return array{reading_text:string,result_json:array<string,mixed>,line_situations:array<int,array<string,mixed>>}|null
     */
    public function generate(
        string $correlationId,
        string $signatureHash,
        string $handedness,
        array $quantized,
        array $baseResultJson,
        array $lineSignals
    ): ?array {
        if (! filter_var(config('palm.llm_enabled', false), FILTER_VALIDATE_BOOL)) {
            return null;
        }

        $input = [
            'signature_hash' => $signatureHash,
            'handedness' => $handedness,
            'quantized_buckets' => $quantized,
            'line_signals' => $lineSignals,
        ];

        try {
            $llmPayload = $this->openRouterClient->generateReading($input, $correlationId);
        } catch (Throwable $exception) {
            Log::warning('LLM reading generation failed, fallback to templates.', [
                'correlation_id' => $correlationId,
                'error' => $exception->getMessage(),
            ]);

            return null;
        }

        $narrative = trim((string) ($llmPayload['narrative'] ?? ''));
        if ($narrative === '') {
            Log::warning('LLM payload missing narrative.', [
                'correlation_id' => $correlationId,
            ]);
            return null;
        }

        $disclaimer = trim((string) ($llmPayload['disclaimer'] ?? ''));
        if ($disclaimer === '') {
            Log::warning('LLM payload missing disclaimer.', [
                'correlation_id' => $correlationId,
            ]);
            return null;
        }

        $lineSituations = $this->normalizeLineSituations(
            is_array($llmPayload['line_situations'] ?? null) ? $llmPayload['line_situations'] : []
        );
        if ($lineSituations === null) {
            Log::warning('LLM payload missing required line_situations fields.', [
                'correlation_id' => $correlationId,
            ]);
            return null;
        }

        $payload = [
            'narrative' => $narrative,
            'disclaimer' => $disclaimer,
            'line_situations' => $lineSituations,
        ];

        $forceEnglish = filter_var(config('palm.llm_force_english', true), FILTER_VALIDATE_BOOL);
        if ($forceEnglish && ! EnglishOnlyGuard::payloadIsEnglish($payload)) {
            Log::warning('OpenRouter output was non-English. Falling back to templates.', [
                'correlation_id' => $correlationId,
            ]);

            return null;
        }

        $resultJson = $baseResultJson;
        $resultJson['reading_style_version'] = 6;
        $resultJson['generator'] = 'openrouter';
        $resultJson['llm_model'] = (string) config('palm.openrouter_model', 'openai/gpt-4o');
        $resultJson['tone'] = 'friendly-professional-llm';
        $resultJson['narrative'] = $narrative;
        $resultJson['disclaimer'] = $disclaimer;
        $resultJson['line_situations'] = $lineSituations;

        return [
            'reading_text' => $narrative,
            'result_json' => $resultJson,
            'line_situations' => $lineSituations,
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $generatedLineSituations
     * @return array<int, array<string, mixed>>|null
     */
    private function normalizeLineSituations(array $generatedLineSituations): ?array
    {
        $indexed = [];

        foreach ($generatedLineSituations as $item) {
            if (! is_array($item)) {
                continue;
            }

            $key = strtolower(trim((string) ($item['key'] ?? '')));
            if ($key === '') {
                continue;
            }

            // Keep line titles stable and user-friendly regardless of LLM output.
            $title = self::LINE_TITLES[$key] ?? trim((string) ($item['title'] ?? ''));
            $situation = trim((string) ($item['situation'] ?? ''));
            $prediction = trim((string) ($item['prediction'] ?? ''));
            $suggestion = trim((string) ($item['suggestion'] ?? ''));

            if ($title === '' || $situation === '' || $prediction === '' || $suggestion === '') {
                continue;
            }

            $indexed[$key] = [
                'key' => $key,
                'title' => $title,
                'situation' => $situation,
                'prediction' => $prediction,
                'suggestion' => $suggestion,
            ];
        }

        $ordered = [];
        foreach (self::LINE_KEYS as $lineKey) {
            if (! isset($indexed[$lineKey])) {
                return null;
            }
            $ordered[] = $indexed[$lineKey];
        }

        return $ordered;
    }
}
