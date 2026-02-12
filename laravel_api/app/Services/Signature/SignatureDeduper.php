<?php

namespace App\Services\Signature;

use App\Models\PalmRead;

class SignatureDeduper
{
    public function findCompletedMatch(string $signatureHash, string $excludePalmReadId): ?PalmRead
    {
        return PalmRead::query()
            ->where('status', 'completed')
            ->where('hand_signature_hash', $signatureHash)
            ->where('id', '!=', $excludePalmReadId)
            ->orderBy('created_at')
            ->first();
    }
}
