<?php

namespace App\Console\Commands;

use App\Models\PalmRead;
use App\Services\Reading\LineSignalBuilder;
use App\Services\Reading\RuleLineSituationGenerator;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class BackfillLineSituationsCommand extends Command
{
    protected $signature = 'palms:backfill-line-situations {--limit=0} {--dry-run}';

    protected $description = 'Backfill missing deterministic line analysis on completed palm readings.';

    public function handle(
        LineSignalBuilder $lineSignalBuilder,
        RuleLineSituationGenerator $lineSituationGenerator,
    ): int {
        $limit = max(0, (int) $this->option('limit'));
        $dryRun = (bool) $this->option('dry-run');
        $query = PalmRead::query()
            ->where('status', 'completed')
            ->where(function ($query): void {
                $query->whereNull('result_json')
                    ->orWhereJsonLength('result_json->line_situations', '<', count(config('palm.line_keys')));
            })
            ->orderBy('created_at');

        if ($limit > 0) {
            $query->limit($limit);
        }

        $processed = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($query->cursor() as $read) {
            $overlay = is_array($read->overlay_json) ? $read->overlay_json : [];
            if (! is_array($overlay['lines'] ?? null)) {
                $skipped++;
                continue;
            }

            try {
                $resultJson = is_array($read->result_json) ? $read->result_json : [];
                if ($this->hasCompleteLineSituations($resultJson['line_situations'] ?? null)) {
                    $skipped++;
                    continue;
                }

                $signals = $lineSignalBuilder->fromOverlay($overlay);
                $situations = $lineSituationGenerator->generate(
                    $signals,
                    is_array($read->quantized_features_json) ? $read->quantized_features_json : [],
                );

                if ($dryRun) {
                    $this->line("Would update: {$read->id}");
                } else {
                    // Only add the recoverable field; preserve narrative, status,
                    // generator metadata, and every other stored result field.
                    $resultJson['line_situations'] = $situations;
                    $resultJson['line_analysis_source'] = 'deterministic-cv';
                    $read->result_json = $resultJson;
                    $read->save();
                }

                $processed++;
            } catch (Throwable $exception) {
                $failed++;
                Log::warning('Failed to backfill palm line situations.', [
                    'palm_read_id' => $read->id,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        $this->info("processed={$processed} skipped={$skipped} failed={$failed}");

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }

    private function hasCompleteLineSituations(mixed $lineSituations): bool
    {
        if (! is_array($lineSituations)) {
            return false;
        }

        $byKey = [];
        foreach ($lineSituations as $entry) {
            if (is_array($entry) && isset($entry['key'])) {
                $byKey[(string) $entry['key']] = $entry;
            }
        }

        foreach (config('palm.line_keys') as $key) {
            $entry = $byKey[$key] ?? null;
            if (! is_array($entry)) {
                return false;
            }

            foreach (['title', 'situation', 'prediction', 'suggestion'] as $field) {
                if (trim((string) ($entry[$field] ?? '')) === '') {
                    return false;
                }
            }
        }

        return true;
    }
}
