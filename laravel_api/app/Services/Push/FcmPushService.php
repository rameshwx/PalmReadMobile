<?php

namespace App\Services\Push;

use App\Models\PushToken;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmPushService
{
    public function configured(): bool
    {
        return $this->serverKey() !== '';
    }

    /**
     * @param array<string, mixed> $data
     * @return array{sent:int, failed:int, invalid_tokens:int}
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): array
    {
        $tokens = $user->pushTokens()->pluck('token')->all();
        return $this->sendToTokens($tokens, $title, $body, $data);
    }

    /**
     * @param array<int, string> $tokens
     * @param array<string, mixed> $data
     * @return array{sent:int, failed:int, invalid_tokens:int}
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): array
    {
        $result = ['sent' => 0, 'failed' => 0, 'invalid_tokens' => 0];
        $cleaned = collect($tokens)
            ->map(static fn ($token): string => trim((string) $token))
            ->filter(static fn (string $token): bool => $token !== '')
            ->unique()
            ->values();

        if ($cleaned->isEmpty()) {
            return $result;
        }

        if (! $this->configured()) {
            Log::warning('Push send skipped because FCM server key is missing.');
            $result['failed'] = $cleaned->count();
            return $result;
        }

        foreach ($cleaned as $token) {
            $sent = $this->sendSingle(
                token: $token,
                title: $title,
                body: $body,
                data: $data,
            );

            if ($sent === true) {
                $result['sent']++;
                continue;
            }

            if ($sent === null) {
                $result['invalid_tokens']++;
                continue;
            }

            $result['failed']++;
        }

        return $result;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function sendSingle(string $token, string $title, string $body, array $data): ?bool
    {
        try {
            $response = Http::timeout(10)
                ->withHeaders([
                    'Authorization' => 'key='.$this->serverKey(),
                    'Content-Type' => 'application/json',
                ])
                ->post($this->endpoint(), [
                    'to' => $token,
                    'priority' => 'high',
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                    ],
                    'data' => $data,
                ]);
        } catch (ConnectionException $exception) {
            Log::warning('FCM connection failed', ['error' => $exception->getMessage()]);
            return false;
        }

        if (! $response->successful()) {
            Log::warning('FCM push failed', [
                'status' => $response->status(),
                'body' => mb_substr($response->body(), 0, 500),
            ]);
            return false;
        }

        /** @var array<string, mixed> $payload */
        $payload = $response->json() ?? [];
        $failure = (int) ($payload['failure'] ?? 0);
        if ($failure <= 0) {
            return true;
        }

        $results = $payload['results'] ?? [];
        $first = is_array($results) ? ($results[0] ?? null) : null;
        $error = is_array($first) ? mb_strtolower((string) ($first['error'] ?? '')) : '';

        if ($error === 'notregistered' || $error === 'invalidregistration') {
            PushToken::query()->where('token', $token)->delete();
            return null;
        }

        return false;
    }

    private function endpoint(): string
    {
        return (string) config('palm.fcm_endpoint', 'https://fcm.googleapis.com/fcm/send');
    }

    private function serverKey(): string
    {
        return trim((string) config('palm.fcm_server_key', ''));
    }
}
