<?php

namespace App\Services\Reading;

class RuleLineSituationGenerator
{
    /**
     * @var array<string, string>
     */
    private const TITLES = [
        'life' => 'Life line',
        'head' => 'Head line',
        'heart' => 'Heart line',
        'fate' => 'Fate line',
        'sun' => 'Sun (Apollo) line',
    ];

    /**
     * Generate a complete, deterministic set of cautious interpretations from
     * CV signals. This is intentionally descriptive rather than predictive.
     *
     * @param array<int, array<string, mixed>> $lineSignals
     * @param array<string, mixed> $quantized
     * @return array<int, array<string, mixed>>
     */
    public function generate(array $lineSignals, array $quantized = []): array
    {
        $indexed = collect($lineSignals)->keyBy('key');
        $situations = [];

        foreach (config('palm.line_keys') as $lineKey) {
            $signal = $indexed->get($lineKey);
            $lineQuantized = is_array($quantized[$lineKey] ?? null) ? $quantized[$lineKey] : [];
            $situations[] = $this->forLine(
                $lineKey,
                is_array($signal) ? $signal : [],
                $lineQuantized,
            );
        }

        return $situations;
    }

    /**
     * @param array<string, mixed> $signal
     * @param array<string, mixed> $quantized
     * @return array<string, string>
     */
    private function forLine(string $key, array $signal, array $quantized): array
    {
        $detected = (bool) ($signal['detected'] ?? false);
        $bucket = (string) ($signal['confidence_bucket'] ?? 'very_low');
        $length = (float) ($signal['length_ratio'] ?? 0.0);
        $quantizedLength = (string) ($quantized['length_bucket'] ?? '');
        if ($length <= 0.0 && $quantizedLength !== '') {
            $length = match ($quantizedLength) {
                'long', 'extended' => 0.30,
                'short', 'compact' => 0.08,
                default => 0.16,
            };
        }
        $quality = $detected ? "with a {$bucket} confidence signal" : 'but it is not clearly detected';

        if (! $detected) {
            return [
                'key' => $key,
                'title' => self::TITLES[$key] ?? ucfirst($key).' line',
                'situation' => "The {$this->label($key)} line is not clearly detected in the stored image, so this part is read cautiously.",
                'prediction' => 'This signal cannot point to a dependable near-term pattern on its own.',
                'suggestion' => 'Use the broader reading as reflection and retake the photo in even light if you want a clearer signal.',
            ];
        }

        $lengthWord = $length >= 0.28 ? 'extended' : ($length >= 0.12 ? 'moderate' : 'compact');
        $content = match ($key) {
            'life' => [
                'situation' => "The Life line appears {$lengthWord} {$quality}, suggesting a rhythm that may benefit from steady recovery.",
                'prediction' => 'A consistent routine may support gradual personal momentum.',
                'suggestion' => 'Protect one simple habit that helps balance effort and rest.',
            ],
            'head' => [
                'situation' => "The Head line appears {$lengthWord} {$quality}, pointing to a practical and observant decision style.",
                'prediction' => 'Clearer priorities may make an upcoming choice feel more manageable.',
                'suggestion' => 'Set a decision boundary when research starts becoming hesitation.',
            ],
            'heart' => [
                'situation' => "The Heart line appears {$lengthWord} {$quality}, reflecting a preference for trust and emotional steadiness.",
                'prediction' => 'Open communication may strengthen an important connection.',
                'suggestion' => 'Share one honest feeling before trying to solve the whole situation.',
            ],
            'fate' => [
                'situation' => "The Fate line appears {$lengthWord} {$quality}, suggesting that direction may develop through repeated effort.",
                'prediction' => 'A small career or responsibility choice may build useful momentum soon.',
                'suggestion' => 'Track one measurable sign of progress each week.',
            ],
            'sun' => [
                'situation' => "The Sun line appears {$lengthWord} {$quality}, highlighting visibility that may grow through authentic work.",
                'prediction' => 'A visible contribution may attract encouraging feedback over time.',
                'suggestion' => 'Share finished work clearly instead of waiting for perfect timing.',
            ],
            default => [
                'situation' => "The {$this->label($key)} line appears {$lengthWord} {$quality}.",
                'prediction' => 'This pattern may become clearer as circumstances develop.',
                'suggestion' => 'Treat this as reflective guidance and compare it with your lived experience.',
            ],
        };

        return [
            'key' => $key,
            'title' => self::TITLES[$key] ?? ucfirst($key).' line',
            'situation' => $content['situation'],
            'prediction' => $content['prediction'],
            'suggestion' => $content['suggestion'],
        ];
    }

    private function label(string $key): string
    {
        return match ($key) {
            'sun' => 'Sun (Apollo)',
            default => ucfirst($key),
        };
    }
}
