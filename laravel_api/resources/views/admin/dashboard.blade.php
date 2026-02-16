@extends('admin.layout', ['title' => 'PalmRead Admin Dashboard'])

@section('content')
    <div class="grid stats" style="margin-bottom: 14px;">
        <div class="card">
            <div class="stat-title">Users</div>
            <div class="stat-value">{{ number_format($usersCount) }}</div>
        </div>
        <div class="card">
            <div class="stat-title">Uploads</div>
            <div class="stat-value">{{ number_format($readsCount) }}</div>
        </div>
        <div class="card">
            <div class="stat-title">Push Tokens</div>
            <div class="stat-value">{{ number_format($pushTokenCount) }}</div>
        </div>
        <div class="card">
            <div class="stat-title">Completed</div>
            <div class="stat-value">{{ number_format($completedCount) }}</div>
        </div>
        <div class="card">
            <div class="stat-title">Processing</div>
            <div class="stat-value">{{ number_format($queuedCount + $processingCount) }}</div>
        </div>
        <div class="card">
            <div class="stat-title">Failed</div>
            <div class="stat-value">{{ number_format($failedCount) }}</div>
        </div>
    </div>

    <div class="card">
        <div class="toolbar">
            <h2 style="margin: 0; font-size: 18px;">Recent Uploads</h2>
            <a class="ghost-btn" href="{{ route('admin.uploads') }}" style="text-decoration: none; display: inline-block;">View all</a>
        </div>
        <table>
            <thead>
            <tr>
                <th>ID</th>
                <th>User</th>
                <th>Status</th>
                <th>Handedness</th>
                <th>Created</th>
                <th>Failure Reason</th>
            </tr>
            </thead>
            <tbody>
            @forelse ($recentReads as $read)
                <tr>
                    <td><code>{{ $read->id }}</code></td>
                    <td>
                        <div>{{ $read->user?->name ?? '-' }}</div>
                        <div class="muted">{{ $read->user?->email ?? '-' }}</div>
                    </td>
                    <td><span class="badge {{ $read->status }}">{{ $read->status }}</span></td>
                    <td>{{ ucfirst($read->handedness ?? 'unknown') }}</td>
                    <td>{{ optional($read->created_at)->format('Y-m-d H:i') }}</td>
                    <td class="muted">{{ $read->failure_reason ?: '-' }}</td>
                </tr>
            @empty
                <tr>
                    <td colspan="6" class="muted">No uploads yet.</td>
                </tr>
            @endforelse
            </tbody>
        </table>
    </div>
@endsection
