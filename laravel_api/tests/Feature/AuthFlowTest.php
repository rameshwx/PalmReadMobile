<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_rejects_case_insensitive_duplicate_email(): void
    {
        User::query()->create([
            'name' => 'Existing',
            'email' => 'existing@example.com',
            'password' => bcrypt('Password123!'),
        ]);

        $response = $this->postJson('/api/auth/register', [
            'name' => 'Duplicate',
            'email' => 'Existing@Example.com',
            'password' => 'Password123!',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_forgot_password_returns_generic_success_message(): void
    {
        $response = $this->postJson('/api/auth/forgot-password', [
            'email' => 'someone@example.com',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['message']);
    }
}
