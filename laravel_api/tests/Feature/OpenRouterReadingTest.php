<?php

namespace Tests\Feature;

use App\Services\Reading\LlmReadingGenerator;
use App\Services\Reading\ReadingGenerator;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class OpenRouterReadingTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config()->set('palm.llm_enabled', true);
        config()->set('palm.llm_force_english', true);
        config()->set('palm.llm_require_success', false);
        config()->set('palm.openrouter_api_key', 'test-openrouter-key');
        config()->set('palm.openrouter_base_url', 'https://openrouter.ai/api/v1');
        config()->set('palm.openrouter_model', 'openai/gpt-4o');
    }

    public function test_openrouter_generates_the_complete_reading_with_one_request(): void
    {
        Http::fake([
            'https://openrouter.ai/api/v1/chat/completions' => Http::response($this->completionPayload(), 200),
        ]);

        $result = app(LlmReadingGenerator::class)->generate(
            correlationId: '11111111-1111-1111-1111-111111111111',
            signatureHash: hash('sha256', 'fixture-signature'),
            handedness: 'left',
            quantized: $this->quantizedBuckets(),
            baseResultJson: ['disclaimer' => 'base disclaimer'],
            lineSignals: $this->lineSignals(),
        );

        $this->assertIsArray($result);
        $this->assertSame('openrouter', $result['result_json']['generator']);
        $this->assertSame('openai/gpt-4o', $result['result_json']['llm_model']);
        $this->assertCount(5, $result['line_situations']);
        $this->assertSame($result['result_json']['narrative'], $result['reading_text']);

        Http::assertSentCount(1);
        Http::assertSent(function (Request $request): bool {
            $data = $request->data();
            $authorization = $request->header('Authorization');
            $authorization = is_array($authorization) ? implode(',', $authorization) : (string) $authorization;
            $serialized = json_encode($data) ?: '';

            return $request->url() === 'https://openrouter.ai/api/v1/chat/completions'
                && str_contains($authorization, 'Bearer test-openrouter-key')
                && ($data['model'] ?? null) === 'openai/gpt-4o'
                && ($data['stream'] ?? null) === false
                && ($data['response_format']['type'] ?? null) === 'json_schema'
                && count($data['messages'] ?? []) === 1
                && str_contains((string) ($data['messages'][0]['content'] ?? ''), 'quantized_buckets')
                && str_contains((string) ($data['messages'][0]['content'] ?? ''), 'line_signals')
                && ! str_contains($serialized, 'data:image')
                && ! str_contains($serialized, 'image_base64');
        });
    }

    public function test_missing_key_falls_back_without_requesting_openrouter(): void
    {
        config()->set('palm.openrouter_api_key', '');
        Http::fake();

        $result = app(ReadingGenerator::class)->generate(
            correlationId: '22222222-2222-2222-2222-222222222222',
            quantized: $this->quantizedBuckets(),
            lineSignals: $this->lineSignals(),
            signatureHash: hash('sha256', 'fixture-signature'),
            handedness: 'left',
        );

        $this->assertSame('rules', $result['result_json']['generator']);
        $this->assertCompleteFallbackLines($result['line_situations']);
        Http::assertNothingSent();
    }

    public function test_http_failure_falls_back_after_one_request(): void
    {
        Http::fake([
            'https://openrouter.ai/api/v1/chat/completions' => Http::response(['error' => 'unavailable'], 503),
        ]);

        $result = app(ReadingGenerator::class)->generate(
            correlationId: '33333333-3333-3333-3333-333333333333',
            quantized: $this->quantizedBuckets(),
            lineSignals: $this->lineSignals(),
            signatureHash: hash('sha256', 'fixture-signature'),
            handedness: 'left',
        );

        $this->assertSame('rules', $result['result_json']['generator']);
        $this->assertCompleteFallbackLines($result['line_situations']);
        Http::assertSentCount(1);
    }

    public function test_timeout_falls_back_after_one_request(): void
    {
        $requestAttempts = 0;
        Http::fake(function () use (&$requestAttempts): never {
            $requestAttempts++;
            throw new ConnectionException('timed out');
        });

        $result = app(ReadingGenerator::class)->generate(
            correlationId: '44444444-4444-4444-4444-444444444444',
            quantized: $this->quantizedBuckets(),
            lineSignals: $this->lineSignals(),
            signatureHash: hash('sha256', 'fixture-signature'),
            handedness: 'left',
        );

        $this->assertSame('rules', $result['result_json']['generator']);
        $this->assertCompleteFallbackLines($result['line_situations']);
        $this->assertSame(1, $requestAttempts);
    }

    public function test_non_english_response_falls_back_without_a_translation_request(): void
    {
        $payload = $this->completionPayload();
        $payload['choices'][0]['message']['content'] = json_encode([
            'narrative' => 'こんにちは。',
            'disclaimer' => 'This is reflective guidance, not a guaranteed prediction.',
            'line_situations' => [
                ['key' => 'life', 'title' => 'Life line', 'situation' => 'Your rhythm is steady.', 'prediction' => 'Progress may build gradually.', 'suggestion' => 'Keep one useful habit.'],
                ['key' => 'head', 'title' => 'Head line', 'situation' => 'You think carefully.', 'prediction' => 'A clear choice may help.', 'suggestion' => 'Set a decision deadline.'],
                ['key' => 'heart', 'title' => 'Heart line', 'situation' => 'You value trust.', 'prediction' => 'Open communication may help.', 'suggestion' => 'Share one honest feeling.'],
                ['key' => 'fate', 'title' => 'Fate line', 'situation' => 'Effort shapes your direction.', 'prediction' => 'Small steps may build momentum.', 'suggestion' => 'Track weekly progress.'],
                ['key' => 'sun', 'title' => 'Sun (Apollo) line', 'situation' => 'Your strengths can be visible.', 'prediction' => 'Good work may receive notice.', 'suggestion' => 'Share finished work clearly.'],
            ],
        ]);

        Http::fake([
            'https://openrouter.ai/api/v1/chat/completions' => Http::response($payload, 200),
        ]);

        $result = app(ReadingGenerator::class)->generate(
            correlationId: '77777777-7777-7777-7777-777777777777',
            quantized: $this->quantizedBuckets(),
            lineSignals: $this->lineSignals(),
            signatureHash: hash('sha256', 'fixture-signature'),
            handedness: 'left',
        );

        $this->assertSame('rules', $result['result_json']['generator']);
        $this->assertCompleteFallbackLines($result['line_situations']);
        Http::assertSentCount(1);
    }

    public function test_malformed_or_incomplete_response_does_not_retry(): void
    {
        Http::fake([
            'https://openrouter.ai/api/v1/chat/completions' => Http::sequence()
                ->push([
                    'choices' => [
                        ['message' => ['content' => 'not-json']],
                    ],
                ], 200)
                ->push([
                    'choices' => [
                        ['message' => ['content' => json_encode([
                            'narrative' => 'A grounded reading.',
                            'disclaimer' => 'This is reflective guidance, not a guaranteed prediction.',
                            'line_situations' => [],
                        ])]],
                    ],
                ], 200),
        ]);

        $first = app(ReadingGenerator::class)->generate(
            correlationId: '55555555-5555-5555-5555-555555555555',
            signatureHash: hash('sha256', 'fixture-signature-1'),
            handedness: 'left',
            quantized: $this->quantizedBuckets(),
            baseResultJson: [],
            lineSignals: $this->lineSignals(),
        );
        $second = app(ReadingGenerator::class)->generate(
            correlationId: '66666666-6666-6666-6666-666666666666',
            signatureHash: hash('sha256', 'fixture-signature-2'),
            handedness: 'left',
            quantized: $this->quantizedBuckets(),
            baseResultJson: [],
            lineSignals: $this->lineSignals(),
        );

        $this->assertSame('rules', $first['result_json']['generator']);
        $this->assertSame('rules', $second['result_json']['generator']);
        $this->assertCompleteFallbackLines($first['line_situations']);
        $this->assertCompleteFallbackLines($second['line_situations']);
        Http::assertSentCount(2);
    }

    /**
     * @return array<string, mixed>
     */
    private function completionPayload(): array
    {
        return [
            'choices' => [[
                'message' => [
                    'content' => json_encode([
                        'narrative' => 'You tend to be steady, observant, thoughtful, and quietly ambitious. You often build progress through consistent choices rather than sudden changes. A practical strength is your ability to notice patterns before acting, while a blind spot can be waiting too long for perfect certainty. This often shows up as careful preparation at work and measured trust in relationships. Your current direction suggests gradual growth through focused priorities and clearer boundaries. Near-term opportunities may reward patience paired with one visible step forward. Protect your energy by simplifying commitments and reviewing what truly matters each week. You have a useful balance of realism and hope, so keep moving with confidence while allowing room for change.',
                        'disclaimer' => 'This is reflective guidance, not a guaranteed prediction.',
                        'line_situations' => [
                            ['key' => 'life', 'title' => 'Life line', 'situation' => 'Your daily rhythm values stability and steady recovery.', 'prediction' => 'A consistent routine may support gradual personal progress.', 'suggestion' => 'Protect one simple habit that keeps your energy balanced.'],
                            ['key' => 'head', 'title' => 'Head line', 'situation' => 'You approach decisions with careful observation and practical thought.', 'prediction' => 'Clearer priorities may improve your next important choice.', 'suggestion' => 'Set a decision deadline when research begins to become hesitation.'],
                            ['key' => 'heart', 'title' => 'Heart line', 'situation' => 'You value trust, reciprocity, and emotional steadiness.', 'prediction' => 'Open communication may deepen an important relationship.', 'suggestion' => 'Share one honest feeling before trying to solve the whole situation.'],
                            ['key' => 'fate', 'title' => 'Fate line', 'situation' => 'Your direction develops through repeated effort and useful adjustments.', 'prediction' => 'Small career choices may create stronger momentum soon.', 'suggestion' => 'Track one measurable progress signal each week.'],
                            ['key' => 'sun', 'title' => 'Sun (Apollo) line', 'situation' => 'Recognition grows when your work reflects your personal strengths.', 'prediction' => 'A visible contribution may attract encouraging feedback.', 'suggestion' => 'Share finished work clearly instead of waiting for perfect timing.'],
                        ],
                    ]),
                ],
            ]],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function quantizedBuckets(): array
    {
        return [
            'life' => ['length_bucket' => 'steady', 'curvature_bucket' => 'steady'],
            'heart' => ['continuity_bucket' => 'balanced'],
            'fate' => ['length_bucket' => 'incremental'],
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function lineSignals(): array
    {
        return [
            ['key' => 'life', 'detected' => true, 'confidence_bucket' => 'high', 'length_ratio' => 0.4],
            ['key' => 'head', 'detected' => true, 'confidence_bucket' => 'medium', 'length_ratio' => 0.3],
            ['key' => 'heart', 'detected' => true, 'confidence_bucket' => 'medium', 'length_ratio' => 0.2],
            ['key' => 'fate', 'detected' => true, 'confidence_bucket' => 'low', 'length_ratio' => 0.1],
            ['key' => 'sun', 'detected' => false, 'confidence_bucket' => 'very_low', 'length_ratio' => 0.0],
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $lines
     */
    private function assertCompleteFallbackLines(array $lines): void
    {
        $this->assertSame(['life', 'head', 'heart', 'fate', 'sun'], array_column($lines, 'key'));
        foreach ($lines as $line) {
            foreach (['title', 'situation', 'prediction', 'suggestion'] as $field) {
                $this->assertIsString($line[$field] ?? null);
                $this->assertNotSame('', trim((string) $line[$field]));
            }
        }
    }
}
