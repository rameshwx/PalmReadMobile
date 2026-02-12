<?php

namespace App\Services\Storage;

use Carbon\CarbonImmutable;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class PalmImageStorage
{
    public function storeUpload(UploadedFile $file): string
    {
        $disk = (string) config('palm.storage_disk', 'palms');

        return (string) $file->store('uploads/'.now()->format('Y/m/d'), ['disk' => $disk]);
    }

    public function absolutePath(string $relativePath): string
    {
        $disk = (string) config('palm.storage_disk', 'palms');

        return (string) Storage::disk($disk)->path($relativePath);
    }

    public function deleteIfExists(?string $relativePath): void
    {
        if (! $relativePath) {
            return;
        }

        $disk = (string) config('palm.storage_disk', 'palms');

        if (Storage::disk($disk)->exists($relativePath)) {
            Storage::disk($disk)->delete($relativePath);
        }
    }

    public function scheduledDeleteAt(): ?CarbonImmutable
    {
        $days = (int) config('palm.image_retention_days', 30);

        if ($days < 0) {
            $days = 30;
        }

        if ($days === 0) {
            return CarbonImmutable::now();
        }

        return CarbonImmutable::now()->addDays($days);
    }
}
