<?php

namespace Tests\Feature;

use App\Models\PalmRead;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class PalmReadFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_palm_read_poll_result_and_submit_feedback(): void
    {
        config()->set('queue.default', 'sync');

        Http::fake([
            '*/analyze' => Http::response([
                'handedness' => 'left',
                'roi_meta' => ['image_w' => 800, 'image_h' => 1200],
                'lines' => [
                    ['key' => 'life', 'confidence' => 0.82, 'points' => [['x' => 100, 'y' => 200], ['x' => 180, 'y' => 320]]],
                    ['key' => 'head', 'confidence' => 0.74, 'points' => [['x' => 120, 'y' => 360], ['x' => 290, 'y' => 390]]],
                ],
                'features' => ['life' => ['length' => 0.58]],
                'quantized_buckets' => [
                    'life' => ['length_bucket' => 'steady', 'curvature_bucket' => 'steady'],
                    'heart' => ['continuity_bucket' => 'balanced'],
                    'fate' => ['length_bucket' => 'incremental'],
                ],
                'hand_signature_hash' => hash('sha256', 'fixture-signature'),
                'processing_ms' => 420,
            ], 200),
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $createResponse = $this->withHeader('Authorization', 'Bearer '.$token)
            ->withHeader('Accept', 'application/json')
            ->withHeader('X-Correlation-Id', '11111111-1111-1111-1111-111111111111')
            ->post('/api/palm-reads', [
                'image' => UploadedFile::fake()->image('hand.jpg', 800, 1200),
                'handedness_hint' => 'left',
            ]);

        $createResponse->assertStatus(202)
            ->assertJsonPath('status', 'queued');

        $readId = $createResponse->json('id');

        $pollResponse = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/palm-reads/'.$readId);

        $pollResponse->assertOk()
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('handedness', 'left')
            ->assertJsonPath('result_json.reading_style_version', 2)
            ->assertJsonPath('result_json.tone', 'friend-professional')
            ->assertJsonCount(5, 'result_json.line_situations')
            ->assertJsonStructure(['reading_text', 'result_json', 'hand_signature_hash']);

        $readingText = (string) $pollResponse->json('reading_text');
        $this->assertNotSame('', trim($readingText));
        $this->assertStringContainsString('To make this useful day to day', $readingText);
        $this->assertStringNotContainsString("\n\n", $readingText);

        $feedbackResponse = $this->withHeader('Authorization', 'Bearer '.$token)
            ->withHeader('X-Correlation-Id', '22222222-2222-2222-2222-222222222222')
            ->postJson('/api/palm-reads/'.$readId.'/feedback', [
                'is_correct' => false,
                'note' => 'Head line appears shifted.',
            ]);

        $feedbackResponse->assertStatus(201)
            ->assertJsonPath('is_correct', false);

        $this->assertDatabaseHas('palm_read_feedback', [
            'palm_read_id' => $readId,
            'is_correct' => 0,
            'note' => 'Head line appears shifted.',
        ]);
    }

    public function test_history_keeps_only_latest_ten_records_and_prunes_old_images(): void
    {
        config()->set('queue.default', 'redis');
        config()->set('palm.storage_disk', 'palms');
        config()->set('palm.history_limit', 10);

        Storage::fake('palms');
        Queue::fake();

        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $firstReadId = null;
        $firstImagePath = null;

        for ($i = 1; $i <= 11; $i++) {
            $response = $this->withHeader('Authorization', 'Bearer '.$token)
                ->withHeader('Accept', 'application/json')
                ->withHeader('X-Correlation-Id', (string) Str::uuid())
                ->post('/api/palm-reads', [
                    'image' => UploadedFile::fake()->image("hand-{$i}.jpg", 800, 1200),
                    'handedness_hint' => 'left',
                ]);

            $response->assertStatus(202);

            $currentReadId = (string) $response->json('id');
            $this->assertNotSame('', $currentReadId);

            if ($i === 1) {
                $firstReadId = $currentReadId;
                $firstImagePath = PalmRead::query()->findOrFail($currentReadId)->image_path;
                Storage::disk('palms')->assertExists($firstImagePath);
            }
        }

        $this->assertNotNull($firstReadId);
        $this->assertNotNull($firstImagePath);

        $remainingCount = PalmRead::query()->where('user_id', $user->id)->count();
        $this->assertSame(10, $remainingCount);

        $this->assertDatabaseMissing('palm_reads', ['id' => $firstReadId]);
        Storage::disk('palms')->assertMissing($firstImagePath);
    }
}
