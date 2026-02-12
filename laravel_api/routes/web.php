<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'palmread-laravel-api',
        'status' => 'ok',
    ]);
});
