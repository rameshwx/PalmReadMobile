<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\PalmRead;
use App\Models\PushToken;
use App\Models\User;
use App\Services\Push\FcmPushService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class AdminDashboardController extends Controller
{
    public function index(): View
    {
        $statusBreakdown = PalmRead::query()
            ->selectRaw('status, COUNT(*) as count')
            ->groupBy('status')
            ->pluck('count', 'status');

        return view('admin.dashboard', [
            'usersCount' => User::query()->count(),
            'readsCount' => PalmRead::query()->count(),
            'pushTokenCount' => PushToken::query()->count(),
            'queuedCount' => (int) ($statusBreakdown['queued'] ?? 0),
            'processingCount' => (int) ($statusBreakdown['processing'] ?? 0),
            'completedCount' => (int) ($statusBreakdown['completed'] ?? 0),
            'failedCount' => (int) ($statusBreakdown['failed'] ?? 0),
            'recentReads' => PalmRead::query()
                ->with('user:id,name,email')
                ->latest()
                ->limit(10)
                ->get(),
        ]);
    }

    public function users(Request $request): View
    {
        $perPage = max(1, (int) config('admin.users_per_page', 25));
        $q = trim((string) $request->query('q', ''));

        $query = User::query()
            ->withCount(['palmReads', 'pushTokens'])
            ->orderByDesc('created_at');

        if ($q !== '') {
            $query->where(function ($builder) use ($q): void {
                $needle = '%'.mb_strtolower($q).'%';
                $builder
                    ->whereRaw('LOWER(name) LIKE ?', [$needle])
                    ->orWhereRaw('LOWER(email) LIKE ?', [$needle]);
            });
        }

        return view('admin.users', [
            'search' => $q,
            'users' => $query->paginate($perPage)->withQueryString(),
        ]);
    }

    public function uploads(Request $request): View
    {
        $perPage = max(1, (int) config('admin.uploads_per_page', 30));
        $status = trim((string) $request->query('status', ''));

        $query = PalmRead::query()
            ->with('user:id,name,email')
            ->orderByDesc('created_at');

        if ($status !== '') {
            $query->where('status', $status);
        }

        return view('admin.uploads', [
            'status' => $status,
            'uploads' => $query->paginate($perPage)->withQueryString(),
        ]);
    }

    public function push(Request $request): View
    {
        $users = User::query()
            ->withCount('pushTokens')
            ->orderBy('email')
            ->limit(200)
            ->get(['id', 'name', 'email']);

        return view('admin.push', [
            'users' => $users,
            'defaultTitle' => trim((string) $request->query('title', 'PalmRead update')),
        ]);
    }

    public function sendPush(Request $request, FcmPushService $fcm): RedirectResponse
    {
        $data = $request->validate([
            'audience' => ['required', 'in:all,user'],
            'user_id' => ['nullable', 'integer', 'exists:users,id'],
            'title' => ['required', 'string', 'max:120'],
            'body' => ['required', 'string', 'max:500'],
            'deep_link' => ['nullable', 'string', 'max:240'],
        ]);

        $audience = $data['audience'];
        if ($audience === 'user' && empty($data['user_id'])) {
            return back()->withErrors(['user_id' => 'Select a target user.'])->withInput();
        }

        $payload = [
            'type' => 'admin_broadcast',
            'deep_link' => trim((string) ($data['deep_link'] ?? '')),
        ];

        if ($audience === 'all') {
            $tokens = PushToken::query()->pluck('token')->all();
            $result = $fcm->sendToTokens($tokens, $data['title'], $data['body'], $payload);
        } else {
            $user = User::query()->findOrFail((int) $data['user_id']);
            $result = $fcm->sendToUser($user, $data['title'], $data['body'], $payload);
        }

        return redirect()
            ->route('admin.push')
            ->with('status', sprintf(
                'Push sent. Delivered: %d, Failed: %d, Invalid tokens removed: %d',
                $result['sent'],
                $result['failed'],
                $result['invalid_tokens'],
            ));
    }
}
