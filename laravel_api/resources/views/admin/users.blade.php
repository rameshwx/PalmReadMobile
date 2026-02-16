@extends('admin.layout', ['title' => 'PalmRead Admin Users'])

@section('content')
    <div class="card">
        <form class="toolbar" method="get" action="{{ route('admin.users') }}">
            <h2 style="margin: 0; font-size: 18px;">Users</h2>
            <div style="display: flex; gap: 8px; align-items: center;">
                <input type="text" name="q" value="{{ $search }}" placeholder="Search name or email">
                <button type="submit">Search</button>
                <a href="{{ route('admin.users') }}" class="ghost-btn" style="text-decoration: none; display: inline-block;">Reset</a>
            </div>
        </form>

        <table>
            <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Uploads</th>
                <th>Push Tokens</th>
                <th>Created</th>
            </tr>
            </thead>
            <tbody>
            @forelse ($users as $user)
                <tr>
                    <td><code>{{ $user->id }}</code></td>
                    <td>{{ $user->name }}</td>
                    <td>{{ $user->email }}</td>
                    <td>{{ $user->palm_reads_count }}</td>
                    <td>{{ $user->push_tokens_count }}</td>
                    <td>{{ optional($user->created_at)->format('Y-m-d H:i') }}</td>
                </tr>
            @empty
                <tr>
                    <td colspan="6" class="muted">No users found.</td>
                </tr>
            @endforelse
            </tbody>
        </table>

        <div class="pagination">
            {{ $users->links() }}
        </div>
    </div>
@endsection
