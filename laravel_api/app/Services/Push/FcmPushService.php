<?php

namespace App\Services\Push;

use App\Models\PushToken;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmPushService
{
    public function configured(): bool
    {
        $projectId = $this->projectId();
        if ($projectId === '') {
            return false;
        }

        return $this->serviceAccount() !== null;
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
            Log::warning('Push send skipped because FCM HTTP v1 credentials are missing.');
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
        $accessToken = $this->accessToken();
        if ($accessToken === '') {
            return false;
        }

        try {
            $response = Http::timeout(10)
                ->withToken($accessToken)
                ->post($this->messagesEndpoint(), [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        'data' => $this->normalizeData($data),
                    ],
                ]);
        } catch (ConnectionException $exception) {
            Log::warning('FCM connection failed', ['error' => $exception->getMessage()]);
            return false;
        }

        if ($response->successful()) {
            return true;
        }

        $payload = $response->json() ?? [];
        $errorInfo = is_array($payload) ? ($payload['error'] ?? null) : null;

        if (is_array($errorInfo)) {
            $details = $errorInfo['details'] ?? [];
            if ($this->isUnregisteredTokenError($details, $errorInfo)) {
                PushToken::query()->where('token', $token)->delete();
                return null;
            }
        }

        // If the token is invalid, FCM often reports INVALID_ARGUMENT.
        $message = is_array($errorInfo) ? (string) ($errorInfo['message'] ?? '') : '';
        $status = is_array($errorInfo) ? (string) ($errorInfo['status'] ?? '') : '';
        $msgLower = mb_strtolower($message);
        $statusLower = mb_strtolower($status);

        if (
            $statusLower === 'invalid_argument' &&
            (str_contains($msgLower, 'registration token') || str_contains($msgLower, 'fcm registration token'))
        ) {
            PushToken::query()->where('token', $token)->delete();
            return null;
        }

        Log::warning('FCM push failed', [
            'status' => $response->status(),
            'body' => mb_substr($response->body(), 0, 800),
        ]);

        if ($response->status() === 401 || $response->status() === 403) {
            // Token might be expired or service account was rotated; force refresh next call.
            Cache::forget($this->accessTokenCacheKey());
        }

        return false;
    }

    /**
     * @param mixed $details
     * @param array<string, mixed> $errorInfo
     */
    private function isUnregisteredTokenError(mixed $details, array $errorInfo): bool
    {
        $status = (string) ($errorInfo['status'] ?? '');
        $message = (string) ($errorInfo['message'] ?? '');
        $statusLower = mb_strtolower($status);
        $messageLower = mb_strtolower($message);

        if ($statusLower === 'not_found' && str_contains($messageLower, 'requested entity was not found')) {
            // Common for unregistered tokens.
            return true;
        }

        if (! is_array($details)) {
            return false;
        }

        foreach ($details as $entry) {
            if (! is_array($entry)) {
                continue;
            }
            $type = (string) ($entry['@type'] ?? '');
            $errorCode = (string) ($entry['errorCode'] ?? '');
            if (
                $type === 'type.googleapis.com/google.firebase.fcm.v1.FcmError' &&
                mb_strtoupper($errorCode) === 'UNREGISTERED'
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     * FCM requires all data payload values to be strings.
     *
     * @param array<string, mixed> $data
     * @return array<string, string>
     */
    private function normalizeData(array $data): array
    {
        $normalized = [];
        foreach ($data as $k => $v) {
            $key = trim((string) $k);
            if ($key === '') {
                continue;
            }
            if (is_string($v)) {
                $normalized[$key] = $v;
            } elseif (is_bool($v)) {
                $normalized[$key] = $v ? 'true' : 'false';
            } elseif (is_numeric($v)) {
                $normalized[$key] = (string) $v;
            } else {
                $normalized[$key] = json_encode($v) ?: '';
            }
        }
        return $normalized;
    }

    private function messagesEndpoint(): string
    {
        $projectId = $this->projectId();
        return sprintf('https://fcm.googleapis.com/v1/projects/%s/messages:send', $projectId);
    }

    private function projectId(): string
    {
        $cfg = trim((string) config('palm.fcm_project_id', ''));
        if ($cfg !== '') {
            return $cfg;
        }

        $sa = $this->serviceAccount();
        if (! is_array($sa)) {
            return '';
        }

        return trim((string) ($sa['project_id'] ?? ''));
    }

    private function accessToken(): string
    {
        $cacheKey = $this->accessTokenCacheKey();
        $cached = Cache::get($cacheKey);
        if (is_string($cached) && trim($cached) !== '') {
            return trim($cached);
        }

        $sa = $this->serviceAccount();
        if (! is_array($sa)) {
            return '';
        }

        $tokenUri = trim((string) ($sa['token_uri'] ?? 'https://oauth2.googleapis.com/token'));
        $clientEmail = trim((string) ($sa['client_email'] ?? ''));
        $privateKey = (string) ($sa['private_key'] ?? '');

        if ($clientEmail === '' || trim($privateKey) === '' || $tokenUri === '') {
            Log::warning('FCM service account is missing required fields.');
            return '';
        }

        $jwt = $this->buildJwtAssertion(
            clientEmail: $clientEmail,
            privateKey: $privateKey,
            tokenUri: $tokenUri,
            scope: 'https://www.googleapis.com/auth/firebase.messaging'
        );

        if ($jwt === '') {
            return '';
        }

        try {
            $response = Http::asForm()
                ->timeout(10)
                ->post($tokenUri, [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $jwt,
                ]);
        } catch (ConnectionException $exception) {
            Log::warning('OAuth token request failed', ['error' => $exception->getMessage()]);
            return '';
        }

        if (! $response->successful()) {
            Log::warning('OAuth token request failed', [
                'status' => $response->status(),
                'body' => mb_substr($response->body(), 0, 800),
            ]);
            return '';
        }

        $payload = $response->json() ?? [];
        $accessToken = is_array($payload) ? (string) ($payload['access_token'] ?? '') : '';
        $expiresIn = is_array($payload) ? (int) ($payload['expires_in'] ?? 3600) : 3600;

        $accessToken = trim($accessToken);
        if ($accessToken === '') {
            return '';
        }

        $ttl = max(60, min(3600, $expiresIn) - 60);
        Cache::put($cacheKey, $accessToken, now()->addSeconds($ttl));

        return $accessToken;
    }

    private function accessTokenCacheKey(): string
    {
        return 'fcm_access_token_v1';
    }

    /**
     * @return array<string, mixed>|null
     */
    private function serviceAccount(): ?array
    {
        $cacheKey = 'fcm_service_account_json';
        $cached = Cache::get($cacheKey);
        if (is_array($cached)) {
            return $cached;
        }

        $raw = $this->loadServiceAccountJson();
        if ($raw === null) {
            return null;
        }

        Cache::put($cacheKey, $raw, now()->addMinutes(10));
        return $raw;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function loadServiceAccountJson(): ?array
    {
        $path = trim((string) config('palm.fcm_service_account_path', ''));
        $base64 = trim((string) config('palm.fcm_service_account_base64', ''));

        $jsonText = '';

        if ($base64 !== '') {
            $decoded = base64_decode($base64, true);
            if (is_string($decoded)) {
                $jsonText = $decoded;
            }
        } elseif ($path !== '' && is_file($path) && is_readable($path)) {
            $content = @file_get_contents($path);
            if (is_string($content)) {
                $jsonText = $content;
            }
        }

        $jsonText = trim($jsonText);
        if ($jsonText === '') {
            return null;
        }

        $parsed = json_decode($jsonText, true);
        if (! is_array($parsed)) {
            return null;
        }

        return $parsed;
    }

    private function buildJwtAssertion(
        string $clientEmail,
        string $privateKey,
        string $tokenUri,
        string $scope
    ): string {
        $iat = time();
        $exp = $iat + 3600;

        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $claims = [
            'iss' => $clientEmail,
            'sub' => $clientEmail,
            'aud' => $tokenUri,
            'iat' => $iat,
            'exp' => $exp,
            'scope' => $scope,
        ];

        $segments = [
            $this->base64UrlEncode(json_encode($header) ?: ''),
            $this->base64UrlEncode(json_encode($claims) ?: ''),
        ];

        $input = implode('.', $segments);
        $signature = '';
        $ok = openssl_sign($input, $signature, $privateKey, OPENSSL_ALGO_SHA256);
        if (! $ok) {
            Log::warning('Failed to sign JWT for OAuth token exchange.');
            return '';
        }

        return $input.'.'.$this->base64UrlEncode($signature);
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
