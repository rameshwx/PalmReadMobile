<?php

namespace App\Services\Reading;

class ReadingRuleEngine
{
    /**
     * @param array<string, mixed> $quantized
     * @return array{result_json: array<string, mixed>, reading_text: string}
     */
    public function generate(array $quantized, string $signatureHash, string $handedness): array
    {
        $personalityBucket = $this->bucketOrDefault($quantized, ['life', 'curvature_bucket'], 'steady');
        $careerBucket = $this->bucketOrDefault($quantized, ['fate', 'length_bucket'], 'incremental');
        $relationshipBucket = $this->bucketOrDefault($quantized, ['heart', 'continuity_bucket'], 'balanced');
        $vitalityBucket = $this->bucketOrDefault($quantized, ['life', 'length_bucket'], 'steady');

        $personalityText = $this->pick(TemplateCatalog::personality(), $personalityBucket, $signatureHash, 0);
        $careerText = $this->pick(TemplateCatalog::career(), $careerBucket, $signatureHash, 1);
        $relationshipText = $this->pick(TemplateCatalog::relationships(), $relationshipBucket, $signatureHash, 2);
        $vitalityText = $this->pick(TemplateCatalog::vitality(), $vitalityBucket, $signatureHash, 3);
        $timingText = $this->pickFlat(TemplateCatalog::timingNotes(), $signatureHash, 4);
        $introText = $this->pickFlat(TemplateCatalog::narrativeIntros(), $signatureHash, 5);
        $timingBridge = $this->pickFlat(TemplateCatalog::timingBridges(), $signatureHash, 6);
        $focusSuggestion = $this->pick(TemplateCatalog::suggestionFocus(), $personalityBucket, $signatureHash, 7);
        $careerSuggestion = $this->pick(TemplateCatalog::suggestionCareer(), $careerBucket, $signatureHash, 8);
        $vitalitySuggestion = $this->pick(TemplateCatalog::suggestionVitality(), $vitalityBucket, $signatureHash, 9);
        $closerText = $this->pickFlat(TemplateCatalog::narrativeClosers(), $signatureHash, 10);

        $readingText = $this->collapseToParagraph([
            $introText,
            $personalityText,
            'For career and wealth, '.$careerText,
            'In relationships, '.$relationshipText,
            'For vitality and energy, '.$vitalityText,
            $timingBridge.' '.$timingText,
            'To make this useful day to day, consider this practical sequence: '.$focusSuggestion.' '.$careerSuggestion.' '.$vitalitySuggestion,
            $closerText,
            'This is a probabilistic interpretation, not certainty.',
        ]);

        $result = [
            'disclaimer' => 'Palm analysis is interpretive and probabilistic, not factual certainty.',
            'handedness' => $handedness,
            'hand_signature_hash' => $signatureHash,
            'reading_style_version' => 2,
            'tone' => 'friend-professional',
            'narrative' => $readingText,
            'suggestions' => [
                $focusSuggestion,
                $careerSuggestion,
                $vitalitySuggestion,
            ],
            'sections' => [
                'personality_summary' => [
                    'bucket' => $personalityBucket,
                    'text' => $personalityText,
                ],
                'career_wealth' => [
                    'bucket' => $careerBucket,
                    'text' => $careerText,
                ],
                'relationships' => [
                    'bucket' => $relationshipBucket,
                    'text' => $relationshipText,
                ],
                'vitality_energy' => [
                    'bucket' => $vitalityBucket,
                    'text' => $vitalityText,
                ],
                'timing_notes' => [
                    'text' => $timingText,
                    'certainty' => 'low',
                ],
            ],
        ];

        return [
            'result_json' => $result,
            'reading_text' => $readingText,
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

    /**
     * @param array<string, array<int, string>> $catalog
     */
    private function pick(array $catalog, string $bucket, string $hash, int $offset): string
    {
        $pool = $catalog[$bucket] ?? reset($catalog);

        return $this->pickFlat($pool, $hash, $offset);
    }

    /**
     * @param array<int, string> $pool
     */
    private function pickFlat(array $pool, string $hash, int $offset): string
    {
        if (count($pool) === 0) {
            return '';
        }

        $chunk = substr($hash, $offset * 2, 2);
        $index = hexdec($chunk ?: '00') % count($pool);

        return $pool[$index];
    }

    /**
     * @param array<int, string> $parts
     */
    private function collapseToParagraph(array $parts): string
    {
        $text = implode(' ', array_filter(array_map(
            static fn (string $part): string => trim($part),
            $parts
        ), static fn (string $part): bool => $part !== ''));

        $collapsed = preg_replace('/\s+/', ' ', $text);

        return trim($collapsed ?? $text);
    }
}
