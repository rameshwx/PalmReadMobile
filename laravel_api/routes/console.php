<?php

use Illuminate\Support\Facades\Artisan;

Artisan::command('health:check', function () {
    $this->info('ok');
});
