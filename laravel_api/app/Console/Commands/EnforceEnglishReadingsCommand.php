<?php

namespace App\Console\Commands;

use App\Models\PalmRead;
use App\Services\Reading\EnglishOnlyGuard;
use App\Services\Reading\OllamaClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class EnforceEnglishReadingsCommand extends Command
{
    protected $signature = 'palms:enforce-english-readings {--limit=0} {--dry-run}';

    protected $description = 'Regenerate stored LLM readings in English if any non-English text is present.';

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

    public function handle(OllamaClient $ollamaClient): int
    {
        $limit = max(0, (int) $this->option('limit'));
        $dryRun = (bool) $this->option('dry-run');

        $query = PalmRead::query()
            ->where('status', 'completed')
            ->whereNotNull('result_json')
            ->where('result_json->generator', 'ollama')
            ->orderByDesc('created_at');

        if ($limit > 0) {
            $query->limit($limit);
        }

        $updated = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($query->cursor() as $read) {
            $resultJson = is_array($read->result_json) ? $read->result_json : [];
            $version = (int) ($resultJson['reading_style_version'] ?? 0);
            if ($version < 5) {
                $skipped++;
                continue;
            }

            $payload = $this->buildPayloadFromRead($read);
            if ($payload === null) {
                $skipped++;
                continue;
            }

            if (EnglishOnlyGuard::payloadIsEnglish($payload)) {
                $skipped++;
                continue;
            }

            if ($dryRun) {
                $this->line("Would regenerate: {$read->id}");
                $updated++;
                continue;
            }

            try {
                $correlationId = (string) ($read->correlation_id ?? '');
                if ($correlationId === '') {
                    $correlationId = (string) Str::uuid();
                }

                $input = $this->buildInputFromRead($read);
                $narrativePayload = $ollamaClient->generateNarrativeAndDisclaimer($input, $correlationId);
                $linePayload = $ollamaClient->generateLineSituations($input, $correlationId);

                $narrative = trim((string) ($narrativePayload['narrative'] ?? ''));
                $disclaimer = trim((string) ($narrativePayload['disclaimer'] ?? ''));
                $normalizedLineSituations = $this->normalizeLineSituations(
                    is_array($linePayload['line_situations'] ?? null) ? $linePayload['line_situations'] : []
                );

                if ($narrative === '' || $disclaimer === '' || $normalizedLineSituations === null) {
                    throw new \RuntimeException('English regeneration returned invalid payload.');
                }

                if (! EnglishOnlyGuard::payloadIsEnglish([
                    'narrative' => $narrative,
                    'disclaimer' => $disclaimer,
                    'line_situations' => $normalizedLineSituations,
                ])) {
                    throw new \RuntimeException('English regeneration still contained non-English content.');
                }

                $resultJson['narrative'] = $narrative;
                $resultJson['disclaimer'] = $disclaimer;
                $resultJson['line_situations'] = $normalizedLineSituations;
                $resultJson['generator'] = 'ollama';
                $resultJson['reading_style_version'] = max((int) ($resultJson['reading_style_version'] ?? 5), 5);
                $resultJson['llm_model'] = (string) config('palm.llm_model', 'llama3.2:1b');
                $resultJson['tone'] = $resultJson['tone'] ?? 'friendly-professional-llm';

                $read->result_json = $resultJson;
                $read->reading_text = $narrative;
                $read->save();

                $updated++;
            } catch (Throwable $exception) {
                $failed++;
                Log::warning('Failed to regenerate reading in English.', [
                    'palm_read_id' => $read->id,
                    'correlation_id' => $read->correlation_id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        $this->info("updated={$updated} skipped={$skipped} failed={$failed}");

        return $failed > 0 ? 1 : 0;
    }

    /**
     * @return array{narrative:string,disclaimer:string,line_situations:array<int,array<string,mixed>>}|null
     */
    private function buildPayloadFromRead(PalmRead $read): ?array
    {
        $resultJson = is_array($read->result_json) ? $read->result_json : [];

        $narrative = trim((string) ($resultJson['narrative'] ?? $read->reading_text ?? ''));
        $disclaimer = trim((string) ($resultJson['disclaimer'] ?? ''));
        $lineSituations = $resultJson['line_situations'] ?? null;

        if ($narrative === '' || $disclaimer === '' || ! is_array($lineSituations) || count($lineSituations) !== 5) {
            return null;
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
    private function buildInputFromRead(PalmRead $read): array
    {
        return [
            'signature_hash' => (string) ($read->hand_signature_hash ?? ''),
            'handedness' => (string) ($read->handedness ?? 'unknown'),
            'quantized_buckets' => is_array($read->quantized_features_json) ? $read->quantized_features_json : [],
            'line_signals' => $this->buildLineSignalsFromOverlay(is_array($read->overlay_json) ? $read->overlay_json : []),
        ];
    }

    /**
     * @param array<string, mixed> $overlay
     * @return array<int, array<string, mixed>>
     */
    private function buildLineSignalsFromOverlay(array $overlay): array
    {
        $image = is_array($overlay['image'] ?? null) ? $overlay['image'] : [];
        $imageWidth = (int) ($image['width'] ?? 0);
        $imageHeight = (int) ($image['height'] ?? 0);
        $lines = is_array($overlay['lines'] ?? null) ? $overlay['lines'] : [];

        $indexed = collect($lines)->keyBy('key');
        $signals = [];

        $diag = sqrt(max(1, ($imageWidth * $imageWidth) + ($imageHeight * $imageHeight)));

        foreach (self::LINE_KEYS as $lineKey) {
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

            $situation = trim((string) ($item['situation'] ?? ''));
            $prediction = trim((string) ($item['prediction'] ?? ''));
            $suggestion = trim((string) ($item['suggestion'] ?? ''));

            if ($situation === '' || $prediction === '' || $suggestion === '') {
                continue;
            }

            $indexed[$key] = [
                'key' => $key,
                'title' => self::LINE_TITLES[$key] ?? trim((string) ($item['title'] ?? '')),
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
