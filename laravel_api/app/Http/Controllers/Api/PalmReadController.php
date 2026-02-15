<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessPalmReadJob;
use App\Models\PalmRead;
use App\Services\Cv\CvClient;
use App\Services\Storage\PalmImageStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Throwable;

class PalmReadController extends Controller
{
    public function __construct(private readonly PalmImageStorage $imageStorage)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $historyLimit = max(1, (int) config('palm.history_limit', 10));

        $reads = PalmRead::query()
            ->where('user_id', $request->user()->id)
            ->orderByDesc('created_at')
            ->paginate($historyLimit);

        return response()->json($reads);
    }

    public function store(Request $request): JsonResponse
    {
        $maxKb = (int) config('palm.upload_max_mb', 8) * 1024;

        $data = $request->validate([
            'image' => ['required', 'file', 'mimes:jpeg,jpg,png,webp', 'max:'.$maxKb],
            'handedness_hint' => ['nullable', 'in:left,right,unknown'],
        ]);

        $uploaded = $data['image'];
        [$imageW, $imageH] = getimagesize($uploaded->getRealPath()) ?: [null, null];

        $storedPath = $this->imageStorage->storeUpload($uploaded);
        $correlationId = (string) $request->attributes->get('correlation_id');

        // Reject obvious non-palm images early, so the user doesn't wait for a queued job to fail.
        try {
            $cv = app(CvClient::class);
            $cv->validate(
                $this->imageStorage->absolutePath($storedPath),
                (string) ($data['handedness_hint'] ?? 'unknown'),
                $correlationId
            );
        } catch (Throwable $exception) {
            $this->imageStorage->deleteIfExists($storedPath);

            $msg = mb_strtolower($exception->getMessage());
            $invalid =
                str_contains($msg, 'hand_not_detected') ||
                str_contains($msg, 'palm_lines_not_detected') ||
                str_contains($msg, 'invalid_image') ||
                str_contains($msg, 'invalid_hand');

            if ($invalid) {
                return response()->json(['detail' => $exception->getMessage()], 422);
            }

            return response()->json(['detail' => 'cv_validation_failed'], 503);
        }

        $palmRead = PalmRead::query()->create([
            'user_id' => $request->user()->id,
            'handedness' => $data['handedness_hint'] ?? 'unknown',
            'status' => 'queued',
            'image_path' => $storedPath,
            'image_w' => $imageW,
            'image_h' => $imageH,
            'correlation_id' => $correlationId,
            'image_delete_after_at' => $this->imageStorage->scheduledDeleteAt(),
        ]);

        ProcessPalmReadJob::dispatch($palmRead->id)->onQueue('palm_reads');
        $this->pruneUserHistory((int) $request->user()->id);

        return response()->json([
            'id' => $palmRead->id,
            'status' => $palmRead->status,
            'correlation_id' => $correlationId,
            'poll_after_seconds' => (int) config('palm.polling_recommended_seconds', 2),
        ], 202);
    }

    public function show(Request $request, PalmRead $palmRead): JsonResponse
    {
        if ((string) $palmRead->user_id !== (string) $request->user()->id) {
            abort(404);
        }

        $resultJson = is_array($palmRead->result_json) ? $palmRead->result_json : [];
        if (! is_array($resultJson['line_situations'] ?? null)) {
            $resultJson['line_situations'] = [];
        }

        return response()->json([
            'id' => $palmRead->id,
            'status' => $palmRead->status,
            'handedness' => $palmRead->handedness,
            'hand_signature_hash' => $palmRead->hand_signature_hash,
            'reading_text' => $palmRead->reading_text,
            'result_json' => $resultJson,
            'processing_ms' => $palmRead->processing_ms,
            'failure_reason' => $palmRead->failure_reason,
            'created_at' => $palmRead->created_at,
            'correlation_id' => $palmRead->correlation_id,
        ]);
    }

    public function overlay(Request $request, PalmRead $palmRead): JsonResponse
    {
        if ((string) $palmRead->user_id !== (string) $request->user()->id) {
            abort(404);
        }

        $overlay = $palmRead->overlay_json ?? [
            'image' => ['width' => $palmRead->image_w, 'height' => $palmRead->image_h],
            'lines' => [],
        ];

        $linesByKey = collect($overlay['lines'] ?? [])->keyBy('key');
        $filled = [];

        foreach (config('palm.line_keys') as $lineKey) {
            $filled[] = $linesByKey->get($lineKey, [
                'key' => $lineKey,
                'confidence' => 0.1,
                'points' => [],
                'missing' => true,
            ]);
        }

        return response()->json([
            'image' => [
                'width' => (int) ($overlay['image']['width'] ?? $palmRead->image_w),
                'height' => (int) ($overlay['image']['height'] ?? $palmRead->image_h),
            ],
            'lines' => $filled,
            'legend' => [
                'life' => '#2E7D32',
                'head' => '#1565C0',
                'heart' => '#C62828',
                'fate' => '#6A1B9A',
                'sun' => '#EF6C00',
            ],
            'hand_signature_hash' => $palmRead->hand_signature_hash,
            'result_id' => $palmRead->id,
        ]);
    }

    public function image(Request $request, PalmRead $palmRead): StreamedResponse
    {
        if ((string) $palmRead->user_id !== (string) $request->user()->id) {
            abort(404);
        }

        if (! $palmRead->image_path) {
            abort(404, 'Image not available.');
        }

        $disk = (string) config('palm.storage_disk', 'palms');
        if (! Storage::disk($disk)->exists($palmRead->image_path)) {
            abort(404, 'Image not found.');
        }

        $stream = Storage::disk($disk)->readStream($palmRead->image_path);
        if ($stream === false) {
            abort(500, 'Failed to read image.');
        }

        return response()->stream(function () use ($stream): void {
            fpassthru($stream);
            fclose($stream);
        }, 200, [
            'Content-Type' => Storage::disk($disk)->mimeType($palmRead->image_path) ?? 'application/octet-stream',
            'Cache-Control' => 'private, max-age=120',
        ]);
    }

    private function pruneUserHistory(int $userId): void
    {
        $historyLimit = max(1, (int) config('palm.history_limit', 10));

        $idsToKeep = PalmRead::query()
            ->where('user_id', $userId)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit($historyLimit)
            ->pluck('id');

        if ($idsToKeep->isEmpty()) {
            return;
        }

        $staleReads = PalmRead::query()
            ->where('user_id', $userId)
            ->whereNotIn('id', $idsToKeep)
            ->get(['id', 'image_path']);

        if ($staleReads->isEmpty()) {
            return;
        }

        foreach ($staleReads as $staleRead) {
            $this->imageStorage->deleteIfExists($staleRead->image_path);
        }

        PalmRead::query()->whereIn('id', $staleReads->pluck('id'))->delete();
    }
}
