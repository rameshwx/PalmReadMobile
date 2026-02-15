<?php

namespace Tests\Feature;

use App\Mail\OtpCodeMail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class OtpAuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_request_otp_sends_mail_and_returns_challenge_payload(): void
    {
        Mail::fake();
        config()->set('palm.otp_debug_echo', true);

        $response = $this->postJson('/api/auth/otp/request', [
            'email' => 'user@example.com',
        ]);

        $response->assertOk()
            ->assertJsonStructure([
                'challenge_id',
                'expires_in_seconds',
                'resend_after_seconds',
                'debug_code',
            ]);

        Mail::assertSent(OtpCodeMail::class);

        $this->assertDatabaseHas('email_otps', [
            'id' => $response->json('challenge_id'),
            'email' => 'user@example.com',
        ]);
    }

    public function test_verify_otp_logs_in_or_creates_user_and_returns_token(): void
    {
        Mail::fake();
        config()->set('palm.otp_debug_echo', true);

        $request = $this->postJson('/api/auth/otp/request', [
            'email' => 'new.user@example.com',
        ])->assertOk();

        $verify = $this->postJson('/api/auth/otp/verify', [
            'email' => 'new.user@example.com',
            'challenge_id' => $request->json('challenge_id'),
            'code' => $request->json('debug_code'),
        ]);

        $verify->assertOk()
            ->assertJsonStructure([
                'user' => ['id', 'name', 'email'],
                'token',
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'new.user@example.com',
        ]);
    }

    public function test_wrong_code_increments_attempts_and_eventually_blocks(): void
    {
        Mail::fake();
        config()->set('palm.otp_debug_echo', true);
        config()->set('palm.otp_max_attempts', 2);

        $request = $this->postJson('/api/auth/otp/request', [
            'email' => 'blocked@example.com',
        ])->assertOk();

        $payload = [
            'email' => 'blocked@example.com',
            'challenge_id' => $request->json('challenge_id'),
            'code' => '00000',
        ];

        $this->postJson('/api/auth/otp/verify', $payload)->assertStatus(422);
        $this->postJson('/api/auth/otp/verify', $payload)->assertStatus(422);
        $this->postJson('/api/auth/otp/verify', $payload)
            ->assertStatus(422)
            ->assertJsonStructure(['message']);
    }

    public function test_requesting_otp_before_resend_cooldown_returns_429(): void
    {
        Mail::fake();
        config()->set('palm.otp_debug_echo', true);
        config()->set('palm.otp_resend_after_seconds', 45);

        $this->postJson('/api/auth/otp/request', [
            'email' => 'cooldown@example.com',
        ])->assertOk();

        $second = $this->postJson('/api/auth/otp/request', [
            'email' => 'cooldown@example.com',
        ]);

        $second->assertStatus(429)
            ->assertJsonStructure(['message', 'resend_after_seconds']);

        $remaining = (int) $second->json('resend_after_seconds');
        $this->assertGreaterThan(0, $remaining);
        $this->assertLessThanOrEqual(45, $remaining);
    }
}

