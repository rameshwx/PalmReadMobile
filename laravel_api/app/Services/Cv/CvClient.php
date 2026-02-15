<?php

namespace App\Services\Cv;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class CvClient
{
    public function validate(string $localPath, string $handednessHint, string $correlationId): array
    {
        $url = rtrim((string) config('palm.cv_service_base_url'), '/').'/validate';

        try {
            $response = Http::timeout(8)
                ->acceptJson()
                ->withHeaders(['X-Correlation-Id' => $correlationId])
                ->post($url, [
                    'local_path' => $localPath,
                    'handedness_hint' => $handednessHint,
                    'correlation_id' => $correlationId,
                ]);
        } catch (ConnectionException $exception) {
            throw new RuntimeException('CV service connection failed: '.$exception->getMessage());
        }

        if (! $response->successful()) {
            $payload = $response->json();
            $detail = null;
            if (is_array($payload)) {
                $detail = $payload['detail'] ?? $payload['message'] ?? null;
            }

            if (is_string($detail) && $detail !== '') {
                throw new RuntimeException($detail);
            }

            throw new RuntimeException('CV service failed with status '.$response->status());
        }

        $payload = $response->json();

        if (! is_array($payload) || ! isset($payload['roi_meta'])) {
            throw new RuntimeException('CV payload missing required fields.');
        }

        return $payload;
    }

    public function analyze(string $localPath, string $handednessHint, string $correlationId): array
    {
        $url = rtrim((string) config('palm.cv_service_base_url'), '/').'/analyze';

        try {
            $response = Http::timeout(8)
                ->acceptJson()
                ->withHeaders(['X-Correlation-Id' => $correlationId])
                ->post($url, [
                    'local_path' => $localPath,
                    'handedness_hint' => $handednessHint,
                    'correlation_id' => $correlationId,
                ]);
        } catch (ConnectionException $exception) {
            throw new RuntimeException('CV service connection failed: '.$exception->getMessage());
        }

        if (! $response->successful()) {
            $payload = $response->json();
            $detail = null;
            if (is_array($payload)) {
                $detail = $payload['detail'] ?? $payload['message'] ?? null;
            }

            if (is_string($detail) && $detail !== '') {
                throw new RuntimeException($detail);
            }

            throw new RuntimeException('CV service failed with status '.$response->status());
        }

        $payload = $response->json();

        if (! is_array($payload) || ! isset($payload['hand_signature_hash'])) {
            throw new RuntimeException('CV payload missing required fields.');
        }

        return $payload;
    }
}
