<?php

use App\Http\Controllers\Admin\AdminDashboardController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'palmread-laravel-api',
        'status' => 'ok',
    ]);
});

Route::middleware(['admin.basic'])->prefix('admin')->group(function (): void {
    Route::get('/', [AdminDashboardController::class, 'index'])->name('admin.dashboard');
    Route::get('/users', [AdminDashboardController::class, 'users'])->name('admin.users');
    Route::get('/uploads', [AdminDashboardController::class, 'uploads'])->name('admin.uploads');
    Route::get('/push', [AdminDashboardController::class, 'push'])->name('admin.push');
    Route::post('/push', [AdminDashboardController::class, 'sendPush'])->name('admin.push.send');
});
