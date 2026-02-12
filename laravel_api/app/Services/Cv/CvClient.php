<?php

namespace App\Services\Cv;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class CvClient
{
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
            throw new RuntimeException('CV service failed with status '.$response->status());
        }

        $payload = $response->json();

        if (! is_array($payload) || ! isset($payload['hand_signature_hash'])) {
            throw new RuntimeException('CV payload missing required fields.');
        }

        return $payload;
    }
}
