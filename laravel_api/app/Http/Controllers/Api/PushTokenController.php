<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PushToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PushTokenController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'min:20', 'max:255'],
            'platform' => ['nullable', 'string', 'max:32'],
            'app_version' => ['nullable', 'string', 'max:64'],
            'device_model' => ['nullable', 'string', 'max:120'],
        ]);

        $tokenValue = trim((string) $data['token']);
        $token = PushToken::query()->firstOrNew(['token' => $tokenValue]);
        $token->user_id = (int) $request->user()->id;
        $token->platform = trim((string) ($data['platform'] ?? 'unknown')) ?: 'unknown';
        $token->app_version = $this->nullableTrim($data['app_version'] ?? null);
        $token->device_model = $this->nullableTrim($data['device_model'] ?? null);
        $token->last_seen_at = now();
        $token->save();

        return response()->json([
            'ok' => true,
            'token_id' => $token->id,
        ]);
    }

    public function unregister(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'min:20', 'max:255'],
        ]);

        PushToken::query()
            ->where('user_id', $request->user()->id)
            ->where('token', trim((string) $data['token']))
            ->delete();

        return response()->json(['ok' => true]);
    }

    private function nullableTrim(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);
        return $trimmed === '' ? null : $trimmed;
    }
}
