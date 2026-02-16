<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PushTokenApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_and_unregister_push_token(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $token = str_repeat('a', 64);

        $this->postJson('/api/push-tokens/register', [
            'token' => $token,
            'platform' => 'android',
            'app_version' => '1.0.0+1',
            'device_model' => 'Pixel Test',
        ])->assertOk()->assertJsonStructure(['ok', 'token_id']);

        $this->assertDatabaseHas('push_tokens', [
            'user_id' => $user->id,
            'token' => $token,
            'platform' => 'android',
        ]);

        $this->postJson('/api/push-tokens/unregister', [
            'token' => $token,
        ])->assertOk()->assertJson(['ok' => true]);

        $this->assertDatabaseMissing('push_tokens', ['token' => $token]);
    }

    public function test_register_moves_existing_token_to_latest_user(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();
        $token = str_repeat('z', 72);

        Sanctum::actingAs($userA);
        $this->postJson('/api/push-tokens/register', [
            'token' => $token,
            'platform' => 'android',
        ])->assertOk();

        Sanctum::actingAs($userB);
        $this->postJson('/api/push-tokens/register', [
            'token' => $token,
            'platform' => 'android',
        ])->assertOk();

        $this->assertDatabaseHas('push_tokens', [
            'token' => $token,
            'user_id' => $userB->id,
        ]);
    }
}
