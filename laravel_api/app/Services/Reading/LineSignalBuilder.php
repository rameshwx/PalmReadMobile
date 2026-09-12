<?php

namespace App\Services\Reading;

class LineSignalBuilder
{
    /**
     * Build the compact, non-image signal contract shared by reading generation
     * and maintenance commands. The raw overlay remains stored separately.
     *
     * @param array<int, array<string, mixed>> $lines
     * @return array<int, array<string, mixed>>
     */
    public function build(array $lines, int $imageWidth, int $imageHeight): array
    {
        $indexed = collect($lines)->keyBy('key');
        $signals = [];
        $diagonal = sqrt(max(1, ($imageWidth * $imageWidth) + ($imageHeight * $imageHeight)));

        foreach (config('palm.line_keys') as $lineKey) {
            $line = $indexed->get($lineKey);
            $confidence = (float) ($line['confidence'] ?? 0.0);
            $missing = (bool) ($line['missing'] ?? true);
            $points = is_array($line['points'] ?? null) ? $line['points'] : [];
            $pointCount = count($points);
            $lengthPx = 0.0;
            $averageY = 0.0;

            for ($i = 1; $i < $pointCount; $i++) {
                $previous = $points[$i - 1];
                $current = $points[$i];
                $lengthPx += hypot(
                    (float) ($current['x'] ?? 0.0) - (float) ($previous['x'] ?? 0.0),
                    (float) ($current['y'] ?? 0.0) - (float) ($previous['y'] ?? 0.0),
                );
            }

            foreach ($points as $point) {
                $averageY += (float) ($point['y'] ?? 0.0);
            }

            $averageY = $pointCount > 0 ? $averageY / $pointCount : 0.0;

            $signals[] = [
                'key' => $lineKey,
                'detected' => ! $missing && $pointCount >= 2,
                'confidence' => round($confidence, 3),
                'confidence_bucket' => $this->confidenceBucket($confidence),
                'point_count' => $pointCount,
                'length_ratio' => round($lengthPx / max(1.0, $diagonal), 4),
                'avg_vertical_ratio' => $imageHeight > 0 ? round($averageY / $imageHeight, 4) : 0.0,
            ];
        }

        return $signals;
    }

    /**
     * @param array<string, mixed> $overlay
     * @return array<int, array<string, mixed>>
     */
    public function fromOverlay(array $overlay): array
    {
        $image = is_array($overlay['image'] ?? null) ? $overlay['image'] : [];
        $lines = is_array($overlay['lines'] ?? null) ? $overlay['lines'] : [];

        return $this->build(
            $lines,
            (int) ($image['width'] ?? 0),
            (int) ($image['height'] ?? 0),
        );
    }

    private function confidenceBucket(float $confidence): string
    {
        if ($confidence < 0.25) {
            return 'very_low';
        }

        if ($confidence < 0.50) {
            return 'low';
        }

        if ($confidence < 0.75) {
            return 'medium';
        }

        return 'high';
    }
}
