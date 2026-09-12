<?php

namespace Tests\Feature;

use App\Models\PalmRead;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class BackfillLineSituationsCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_backfill_adds_lines_without_replacing_existing_reading_and_is_idempotent(): void
    {
        $user = User::factory()->create();
        $read = PalmRead::query()->create([
            'user_id' => $user->id,
            'handedness' => 'left',
            'status' => 'completed',
            'image_w' => 800,
            'image_h' => 1200,
            'correlation_id' => (string) Str::uuid(),
            'reading_text' => 'The existing narrative must remain unchanged.',
            'result_json' => [
                'generator' => 'rules',
                'narrative' => 'The existing narrative must remain unchanged.',
                'line_situations' => [],
            ],
            'quantized_features_json' => [
                'fate' => ['length_bucket' => 'incremental'],
            ],
            'overlay_json' => [
                'image' => ['width' => 800, 'height' => 1200],
                'lines' => [
                    ['key' => 'life', 'confidence' => 0.9, 'missing' => false, 'points' => [
                        ['x' => 100, 'y' => 200], ['x' => 200, 'y' => 400],
                    ]],
                    ['key' => 'fate', 'confidence' => 0.6, 'missing' => false, 'points' => [
                        ['x' => 300, 'y' => 700], ['x' => 320, 'y' => 500],
                    ]],
                ],
            ],
        ]);

        $this->artisan('palms:backfill-line-situations')
            ->expectsOutput('processed=1 skipped=0 failed=0')
            ->assertExitCode(0);

        $read->refresh();
        $this->assertSame('completed', $read->status);
        $this->assertSame('The existing narrative must remain unchanged.', $read->reading_text);
        $this->assertSame($read->reading_text, $read->result_json['narrative']);
        $this->assertSame(
            ['life', 'head', 'heart', 'fate', 'sun'],
            array_column($read->result_json['line_situations'], 'key'),
        );

        $this->artisan('palms:backfill-line-situations')
            ->expectsOutput('processed=0 skipped=0 failed=0')
            ->assertExitCode(0);
    }

    public function test_backfill_skips_completed_readings_without_an_overlay(): void
    {
        $user = User::factory()->create();
        PalmRead::query()->create([
            'user_id' => $user->id,
            'handedness' => 'unknown',
            'status' => 'completed',
            'correlation_id' => (string) Str::uuid(),
            'result_json' => ['line_situations' => []],
            'reading_text' => 'Stored narrative',
        ]);

        $this->artisan('palms:backfill-line-situations')
            ->expectsOutput('processed=0 skipped=1 failed=0')
            ->assertExitCode(0);
    }
}
