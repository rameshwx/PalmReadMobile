<?php

namespace App\Jobs;

use App\Models\PalmRead;
use App\Services\Cv\CvClient;
use App\Services\Reading\ReadingGenerator;
use App\Services\Signature\SignatureDeduper;
use App\Services\Storage\PalmImageStorage;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Throwable;

class ProcessPalmReadJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;

    /**
     * @var array<int, int>
     */
    public array $backoff = [5, 15];

    public function __construct(private readonly string $palmReadId)
    {
    }

    public function handle(
        CvClient $cvClient,
        ReadingGenerator $readingGenerator,
        SignatureDeduper $deduper,
        PalmImageStorage $storage
    ): void {
        $palmRead = PalmRead::query()->find($this->palmReadId);
        if (! $palmRead) {
            return;
        }

        $correlationId = (string) $palmRead->correlation_id;

        try {
            $palmRead->update(['status' => 'processing']);

            $localPath = $storage->absolutePath($palmRead->image_path);
            $cvResult = $cvClient->analyze($localPath, $palmRead->handedness, $correlationId);

            $overlay = $this->normalizeOverlay(
                $cvResult['lines'] ?? [],
                (int) ($cvResult['roi_meta']['image_w'] ?? $palmRead->image_w),
                (int) ($cvResult['roi_meta']['image_h'] ?? $palmRead->image_h)
            );

            $quantized = is_array($cvResult['quantized_buckets'] ?? null) ? $cvResult['quantized_buckets'] : [];
            $signatureHash = (string) $cvResult['hand_signature_hash'];
            $lineSignals = $this->buildLineSignals(
                $overlay['lines'] ?? [],
                (int) ($overlay['image']['width'] ?? 0),
                (int) ($overlay['image']['height'] ?? 0)
            );

            $existing = $deduper->findCompletedMatch($signatureHash, $palmRead->id);

            $palmRead->handedness = (string) ($cvResult['handedness'] ?? $palmRead->handedness ?? 'unknown');
            $palmRead->features_json = $cvResult['features'] ?? null;
            $palmRead->quantized_features_json = $quantized;
            $palmRead->roi_meta = $cvResult['roi_meta'] ?? null;
            $palmRead->overlay_json = $overlay;
            $palmRead->hand_signature_hash = $signatureHash;
            $palmRead->processing_ms = (int) ($cvResult['processing_ms'] ?? 0);

            $reading = null;
            if ($existing) {
                if ($this->isLegacyReadingPayload($existing->result_json, $existing->reading_text)) {
                    $reading = $readingGenerator->generate(
                        correlationId: $correlationId,
                        quantized: $quantized,
                        lineSignals: $lineSignals,
                        signatureHash: $signatureHash,
                        handedness: $palmRead->handedness
                    );

                    $existing->result_json = $reading['result_json'];
                    $existing->reading_text = $reading['reading_text'];
                    $existing->save();
                }

                $resultJson = is_array($existing->result_json) ? $existing->result_json : [];
                $palmRead->result_json = $resultJson;
                $palmRead->reading_text = $existing->reading_text;
                $palmRead->deduped_from_read_id = $existing->id;
            } else {
                $reading = $readingGenerator->generate(
                    correlationId: $correlationId,
                    quantized: $quantized,
                    lineSignals: $lineSignals,
                    signatureHash: $signatureHash,
                    handedness: $palmRead->handedness
                );

                $palmRead->result_json = $reading['result_json'];
                $palmRead->reading_text = $reading['reading_text'];
                $palmRead->deduped_from_read_id = null;
            }

            $palmRead->status = 'completed';
            $palmRead->failure_reason = null;
            $palmRead->save();

            if ((int) config('palm.image_retention_days', 30) === 0) {
                $storage->deleteIfExists($palmRead->image_path);
                $palmRead->image_path = null;
                $palmRead->save();
            }

            Log::info('Palm read completed', [
                'palm_read_id' => $palmRead->id,
                'correlation_id' => $correlationId,
                'processing_ms' => $palmRead->processing_ms,
                'signature_hash' => $signatureHash,
                'deduped_from' => $palmRead->deduped_from_read_id,
            ]);
        } catch (Throwable $exception) {
            $palmRead->status = 'failed';
            $palmRead->failure_reason = mb_substr($exception->getMessage(), 0, 250);
            $palmRead->save();

            Log::error('Palm read failed', [
                'palm_read_id' => $palmRead->id,
                'correlation_id' => $correlationId,
                'error' => $exception->getMessage(),
            ]);

            $msg = mb_strtolower($exception->getMessage());
            $nonRetriable =
                str_contains($msg, 'hand_not_detected') ||
                str_contains($msg, 'palm_lines_not_detected') ||
                str_contains($msg, 'invalid_image') ||
                str_contains($msg, 'invalid_hand');

            if ($nonRetriable) {
                // User submitted an invalid input. Retrying won't help.
                return;
            }

            throw $exception;
        }
    }

    /**
     * @param array<int, array<string, mixed>> $lines
     * @return array<string, mixed>
     */
    private function normalizeOverlay(array $lines, int $width, int $height): array
    {
        $lineKeys = config('palm.line_keys');
        $indexed = collect($lines)->keyBy('key');
        $normalizedLines = [];

        foreach ($lineKeys as $key) {
            $candidate = $indexed->get($key);
            if (! is_array($candidate)) {
                $normalizedLines[] = [
                    'key' => $key,
                    'confidence' => 0.1,
                    'points' => [],
                    'missing' => true,
                ];
                continue;
            }

            $normalizedLines[] = [
                'key' => $key,
                'confidence' => (float) ($candidate['confidence'] ?? 0.1),
                'points' => array_map(static fn (array $p): array => [
                    'x' => (float) ($p['x'] ?? 0.0),
                    'y' => (float) ($p['y'] ?? 0.0),
                ], $candidate['points'] ?? []),
                'missing' => ! isset($candidate['points']) || count($candidate['points']) < 2,
            ];
        }

        return [
            'image' => [
                'width' => $width,
                'height' => $height,
            ],
            'lines' => $normalizedLines,
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $lines
     * @return array<int, array<string, mixed>>
     */
    private function buildLineSignals(array $lines, int $imageWidth, int $imageHeight): array
    {
        $indexed = collect($lines)->keyBy('key');
        $signals = [];

        $diag = sqrt(max(1, ($imageWidth * $imageWidth) + ($imageHeight * $imageHeight)));

        foreach (config('palm.line_keys') as $lineKey) {
            $line = $indexed->get($lineKey);
            $confidence = (float) ($line['confidence'] ?? 0.0);
            $missing = (bool) ($line['missing'] ?? true);

            $points = is_array($line['points'] ?? null) ? $line['points'] : [];
            $pointCount = count($points);
            $lengthPx = 0.0;
            $avgY = 0.0;
            $validPoints = 0;

            for ($i = 1; $i < $pointCount; $i++) {
                $prev = $points[$i - 1];
                $curr = $points[$i];
                $x1 = (float) ($prev['x'] ?? 0.0);
                $y1 = (float) ($prev['y'] ?? 0.0);
                $x2 = (float) ($curr['x'] ?? 0.0);
                $y2 = (float) ($curr['y'] ?? 0.0);
                $lengthPx += hypot($x2 - $x1, $y2 - $y1);
            }

            foreach ($points as $point) {
                $avgY += (float) ($point['y'] ?? 0.0);
                $validPoints++;
            }

            $avgY = $validPoints > 0 ? $avgY / $validPoints : 0.0;

            $signals[] = [
                'key' => $lineKey,
                'detected' => ! $missing && $pointCount >= 2,
                'confidence' => round($confidence, 3),
                'confidence_bucket' => $this->confidenceBucket($confidence),
                'point_count' => $pointCount,
                'length_ratio' => round($lengthPx / max(1.0, $diag), 4),
                'avg_vertical_ratio' => $imageHeight > 0 ? round($avgY / $imageHeight, 4) : 0.0,
            ];
        }

        return $signals;
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

    /**
     * @param array<string, mixed>|null $resultJson
     */
    private function isLegacyReadingPayload(?array $resultJson, ?string $readingText): bool
    {
        if (! is_array($resultJson)) {
            return true;
        }

        $version = $this->normalizeVersion($resultJson['reading_style_version'] ?? null);
        $generator = strtolower(trim((string) ($resultJson['generator'] ?? '')));
        $hasReadingText = is_string($readingText) && trim($readingText) !== '';
        $hasNarrative = is_string($resultJson['narrative'] ?? null) && trim((string) $resultJson['narrative']) !== '';
        $hasDisclaimer = is_string($resultJson['disclaimer'] ?? null) && trim((string) $resultJson['disclaimer']) !== '';
        $hasLineSituations = $this->hasAllLineSituations($resultJson['line_situations'] ?? null);

        $isModern = (
            $generator === 'ollama' &&
            $version >= 6 &&
            $hasReadingText &&
            $hasNarrative &&
            $hasDisclaimer &&
            $hasLineSituations
        );

        if (! $isModern) {
            return true;
        }

        $forceEnglish = filter_var(config('palm.llm_force_english', true), FILTER_VALIDATE_BOOL);
        if ($forceEnglish && ! \App\Services\Reading\EnglishOnlyGuard::resultJsonIsEnglish($resultJson, $readingText)) {
            return true;
        }

        return false;
    }

    private function normalizeVersion(mixed $version): int
    {
        if (is_int($version)) {
            return $version;
        }

        if (is_string($version) && ctype_digit($version)) {
            return (int) $version;
        }

        return 0;
    }

    private function hasAllLineSituations(mixed $lineSituations): bool
    {
        if (! is_array($lineSituations)) {
            return false;
        }

        $byKey = [];
        foreach ($lineSituations as $entry) {
            if (! is_array($entry)) {
                continue;
            }
            $key = (string) ($entry['key'] ?? '');
            if ($key !== '') {
                $byKey[$key] = $entry;
            }
        }

        foreach (config('palm.line_keys') as $lineKey) {
            $entry = $byKey[$lineKey] ?? null;
            if (! is_array($entry)) {
                return false;
            }

            foreach (['title', 'situation', 'prediction', 'suggestion'] as $requiredTextField) {
                if (trim((string) ($entry[$requiredTextField] ?? '')) === '') {
                    return false;
                }
            }
        }

        return true;
    }
}
