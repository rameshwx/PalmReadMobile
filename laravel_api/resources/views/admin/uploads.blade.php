@extends('admin.layout', ['title' => 'PalmRead Admin Uploads'])

@section('content')
    <div class="card">
        <form class="toolbar" method="get" action="{{ route('admin.uploads') }}">
            <h2 style="margin: 0; font-size: 18px;">User Uploads</h2>
            <div style="display: flex; gap: 8px; align-items: center;">
                <select name="status">
                    <option value="">All statuses</option>
                    @foreach (['queued', 'processing', 'completed', 'failed'] as $option)
                        <option value="{{ $option }}" @selected($status === $option)>{{ ucfirst($option) }}</option>
                    @endforeach
                </select>
                <button type="submit">Filter</button>
                <a href="{{ route('admin.uploads') }}" class="ghost-btn" style="text-decoration: none; display: inline-block;">Reset</a>
            </div>
        </form>

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
            @forelse ($uploads as $upload)
                <tr>
                    <td><code>{{ $upload->id }}</code></td>
                    <td>
                        <div>{{ $upload->user?->name ?? '-' }}</div>
                        <div class="muted">{{ $upload->user?->email ?? '-' }}</div>
                    </td>
                    <td><span class="badge {{ $upload->status }}">{{ $upload->status }}</span></td>
                    <td>{{ ucfirst($upload->handedness ?? 'unknown') }}</td>
                    <td>{{ optional($upload->created_at)->format('Y-m-d H:i') }}</td>
                    <td class="muted">{{ $upload->failure_reason ?: '-' }}</td>
                </tr>
            @empty
                <tr>
                    <td colspan="6" class="muted">No uploads found.</td>
                </tr>
            @endforelse
            </tbody>
        </table>

        <div class="pagination">
            {{ $uploads->links() }}
        </div>
    </div>
@endsection
