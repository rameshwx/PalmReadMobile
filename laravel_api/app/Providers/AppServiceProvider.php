<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // App-specific service bindings can be added here.
    }

    public function boot(): void
    {
    }
}
