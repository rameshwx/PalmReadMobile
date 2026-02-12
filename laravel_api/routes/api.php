<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PalmReadController;
use App\Http\Controllers\Api\PalmReadFeedbackController;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'service' => 'laravel_api',
        'time' => now()->toIso8601String(),
    ]);
});

Route::prefix('auth')->group(function (): void {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
    Route::post('/reset-password', [AuthController::class, 'resetPassword']);
});

Route::middleware(['auth:sanctum', 'correlation.id'])->group(function (): void {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::get('/palm-reads', [PalmReadController::class, 'index']);
    Route::post('/palm-reads', [PalmReadController::class, 'store']);
    Route::get('/palm-reads/{palmRead}', [PalmReadController::class, 'show']);
    Route::get('/palm-reads/{palmRead}/image', [PalmReadController::class, 'image']);
    Route::get('/palm-reads/{palmRead}/overlay', [PalmReadController::class, 'overlay']);
    Route::post('/palm-reads/{palmRead}/feedback', [PalmReadFeedbackController::class, 'store']);
});
