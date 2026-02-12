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

    public function __construct(private readonly OllamaClient $ollamaClient)
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
            $narrativePayload = $this->ollamaClient->generateNarrativeAndDisclaimer($input, $correlationId);
            $linePayload = $this->ollamaClient->generateLineSituations($input, $correlationId);
        } catch (Throwable $exception) {
            Log::warning('LLM reading generation failed, fallback to templates.', [
                'correlation_id' => $correlationId,
                'error' => $exception->getMessage(),
            ]);

            return null;
        }

        $narrative = trim((string) ($narrativePayload['narrative'] ?? ''));
        if ($narrative === '') {
            Log::warning('LLM payload missing narrative.', [
                'correlation_id' => $correlationId,
            ]);
            return null;
        }

        $disclaimer = trim((string) ($narrativePayload['disclaimer'] ?? ''));
        if ($disclaimer === '') {
            Log::warning('LLM payload missing disclaimer.', [
                'correlation_id' => $correlationId,
            ]);
            return null;
        }

        $lineSituations = $this->normalizeLineSituations(
            is_array($linePayload['line_situations'] ?? null) ? $linePayload['line_situations'] : []
        );
        if ($lineSituations === null) {
            Log::warning('LLM payload missing required line_situations fields.', [
                'correlation_id' => $correlationId,
            ]);
            return null;
        }

        $englishPayload = $this->enforceEnglishPayload(
            payload: [
                'narrative' => $narrative,
                'disclaimer' => $disclaimer,
                'line_situations' => $lineSituations,
            ],
            correlationId: $correlationId,
            signatureHash: $signatureHash
        );

        if ($englishPayload === null) {
            return null;
        }

        $narrative = $englishPayload['narrative'];
        $disclaimer = $englishPayload['disclaimer'];
        $lineSituations = $englishPayload['line_situations'];

        $resultJson = $baseResultJson;
        $resultJson['reading_style_version'] = 6;
        $resultJson['generator'] = 'ollama';
        $resultJson['llm_model'] = (string) config('palm.llm_model', 'llama3.2:1b');
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

    /**
     * @param array{narrative:string,disclaimer:string,line_situations:array<int,array<string,mixed>>} $payload
     * @return array{narrative:string,disclaimer:string,line_situations:array<int,array<string,mixed>>}|null
     */
    private function enforceEnglishPayload(array $payload, string $correlationId, string $signatureHash): ?array
    {
        $forceEnglish = filter_var(config('palm.llm_force_english', true), FILTER_VALIDATE_BOOL);
        if (! $forceEnglish || EnglishOnlyGuard::payloadIsEnglish($payload)) {
            return $payload;
        }

        Log::info('LLM output was non-English. Rewriting to English.', [
            'correlation_id' => $correlationId,
        ]);

        try {
            $rewritten = $this->ollamaClient->rewriteReadingInEnglish($payload, $correlationId, $signatureHash);
        } catch (Throwable $exception) {
            Log::warning('English rewrite failed for LLM payload.', [
                'correlation_id' => $correlationId,
                'error' => $exception->getMessage(),
            ]);

            return null;
        }

        $narrative = trim((string) ($rewritten['narrative'] ?? ''));
        $disclaimer = trim((string) ($rewritten['disclaimer'] ?? ''));
        if ($narrative === '' || $disclaimer === '') {
            Log::warning('English rewrite returned empty narrative/disclaimer.', [
                'correlation_id' => $correlationId,
            ]);

            return null;
        }

        $lineSituations = $this->normalizeLineSituations(
            is_array($rewritten['line_situations'] ?? null) ? $rewritten['line_situations'] : []
        );
        if ($lineSituations === null) {
            Log::warning('English rewrite returned invalid line_situations.', [
                'correlation_id' => $correlationId,
            ]);

            return null;
        }

        $normalizedPayload = [
            'narrative' => $narrative,
            'disclaimer' => $disclaimer,
            'line_situations' => $lineSituations,
        ];

        if (! EnglishOnlyGuard::payloadIsEnglish($normalizedPayload)) {
            Log::warning('English rewrite still produced non-English text.', [
                'correlation_id' => $correlationId,
            ]);

            return null;
        }

        return $normalizedPayload;
    }
}
