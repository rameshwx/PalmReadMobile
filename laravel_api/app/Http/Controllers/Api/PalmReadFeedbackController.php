<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PalmRead;
use App\Models\PalmReadFeedback;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PalmReadFeedbackController extends Controller
{
    public function store(Request $request, PalmRead $palmRead): JsonResponse
    {
        if ((string) $palmRead->user_id !== (string) $request->user()->id) {
            abort(404);
        }

        $data = $request->validate([
            'is_correct' => ['required', 'boolean'],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $feedback = PalmReadFeedback::query()->create([
            'palm_read_id' => $palmRead->id,
            'user_id' => $request->user()->id,
            'is_correct' => $data['is_correct'],
            'note' => $data['note'] ?? null,
            'correlation_id' => $request->attributes->get('correlation_id'),
        ]);

        return response()->json([
            'id' => $feedback->id,
            'palm_read_id' => $feedback->palm_read_id,
            'is_correct' => $feedback->is_correct,
            'note' => $feedback->note,
            'created_at' => $feedback->created_at,
        ], 201);
    }
}
