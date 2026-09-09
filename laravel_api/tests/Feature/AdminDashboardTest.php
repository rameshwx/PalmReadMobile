<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_dashboard_requires_basic_auth(): void
    {
        $testPassword = bin2hex(random_bytes(16));

        config()->set('admin.username', 'admin');
        config()->set('admin.password', $testPassword);

        $this->get('/admin')->assertStatus(401);
    }

    public function test_admin_dashboard_allows_valid_basic_auth(): void
    {
        $testPassword = bin2hex(random_bytes(16));

        config()->set('admin.username', 'admin');
        config()->set('admin.password', $testPassword);

        $headers = [
            'Authorization' => 'Basic '.base64_encode('admin:'.$testPassword),
        ];

        $this->withHeaders($headers)->get('/admin')->assertOk();
        $this->withHeaders($headers)->get('/admin/users')->assertOk();
        $this->withHeaders($headers)->get('/admin/uploads')->assertOk();
        $this->withHeaders($headers)->get('/admin/push')->assertOk();
    }
}
