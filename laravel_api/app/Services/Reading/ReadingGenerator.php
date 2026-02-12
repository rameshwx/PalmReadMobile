<?php

namespace App\Services\Reading;

use RuntimeException;

class ReadingGenerator
{
    public function __construct(
        private readonly ReadingRuleEngine $ruleEngine,
        private readonly LlmReadingGenerator $llmGenerator
    ) {
    }

    /**
     * @param array<string, mixed> $quantized
     * @param array<int, array<string, mixed>> $lineSignals
     * @return array{result_json: array<string, mixed>, reading_text: string, line_situations: array<int, array<string, mixed>>}
     */
    public function generate(
        string $correlationId,
        array $quantized,
        array $lineSignals,
        string $signatureHash,
        string $handedness
    ): array {
        $llmEnabled = filter_var(config('palm.llm_enabled', false), FILTER_VALIDATE_BOOL);
        $llmRequireSuccess = filter_var(config('palm.llm_require_success', false), FILTER_VALIDATE_BOOL);

        $baseResultJson = $this->llmBaseResultJson($quantized, $signatureHash, $handedness);
        if (! $llmEnabled) {
            $ruleBase = $this->ruleEngine->generate($quantized, $signatureHash, $handedness);
            $baseResultJson = is_array($ruleBase['result_json'] ?? null) ? $ruleBase['result_json'] : [];
        }

        $llm = $this->llmGenerator->generate(
            correlationId: $correlationId,
            signatureHash: $signatureHash,
            handedness: $handedness,
            quantized: $quantized,
            baseResultJson: $baseResultJson,
            lineSignals: $lineSignals
        );

        if ($llm) {
            return [
                'result_json' => $llm['result_json'],
                'reading_text' => $llm['reading_text'],
                'line_situations' => $llm['line_situations'],
            ];
        }

        if ($llmEnabled && $llmRequireSuccess) {
            throw new RuntimeException('LLM reading generation is required but unavailable.');
        }

        $base = $this->ruleEngine->generate($quantized, $signatureHash, $handedness);
        $baseResultJson = is_array($base['result_json'] ?? null) ? $base['result_json'] : [];
        $baseText = (string) ($base['reading_text'] ?? '');
        $baseResultJson['generator'] = 'rules';
        $baseResultJson['reading_style_version'] = $baseResultJson['reading_style_version'] ?? 2;
        $baseResultJson['line_situations'] = [];

        return [
            'result_json' => $baseResultJson,
            'reading_text' => $baseText,
            'line_situations' => [],
        ];
    }

    /**
     * @param array<string, mixed> $quantized
     * @return array<string, mixed>
     */
    private function llmBaseResultJson(array $quantized, string $signatureHash, string $handedness): array
    {
        return [
            'disclaimer' => 'Palm analysis is interpretive and probabilistic, not factual certainty.',
            'handedness' => $handedness,
            'hand_signature_hash' => $signatureHash,
            'signal_summary' => [
                'life_curvature_bucket' => $this->bucketOrDefault($quantized, ['life', 'curvature_bucket'], 'steady'),
                'fate_length_bucket' => $this->bucketOrDefault($quantized, ['fate', 'length_bucket'], 'incremental'),
                'heart_continuity_bucket' => $this->bucketOrDefault($quantized, ['heart', 'continuity_bucket'], 'balanced'),
                'life_length_bucket' => $this->bucketOrDefault($quantized, ['life', 'length_bucket'], 'steady'),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $quantized
     * @param array<int, string> $path
     */
    private function bucketOrDefault(array $quantized, array $path, string $default): string
    {
        $value = $quantized;
        foreach ($path as $segment) {
            if (! is_array($value) || ! array_key_exists($segment, $value)) {
                return $default;
            }

            $value = $value[$segment];
        }

        return is_string($value) ? $value : $default;
    }
}
