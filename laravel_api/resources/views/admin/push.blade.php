@extends('admin.layout', ['title' => 'PalmRead Admin Push'])

@section('content')
    <div class="card" style="max-width: 760px;">
        <h2 style="margin: 0 0 12px; font-size: 18px;">Send Push Notification</h2>
        <p class="muted" style="margin: 0 0 14px;">
            This sends mobile push notifications to registered devices. Configure <code>PALM_FCM_SERVER_KEY</code> on the API server first.
        </p>

        <form method="post" action="{{ route('admin.push.send') }}">
            @csrf
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 12px;">
                <div>
                    <label for="audience" class="muted" style="display: block; margin-bottom: 6px;">Audience</label>
                    <select id="audience" name="audience" required>
                        <option value="all" @selected(old('audience', 'all') === 'all')>All devices</option>
                        <option value="user" @selected(old('audience') === 'user')>Specific user</option>
                    </select>
                    @error('audience')<div class="error">{{ $message }}</div>@enderror
                </div>
                <div>
                    <label for="user_id" class="muted" style="display: block; margin-bottom: 6px;">User (when audience = user)</label>
                    <select id="user_id" name="user_id">
                        <option value="">Select user</option>
                        @foreach ($users as $user)
                            <option value="{{ $user->id }}" @selected((string) old('user_id') === (string) $user->id)>
                                {{ $user->email }} ({{ $user->push_tokens_count }} tokens)
                            </option>
                        @endforeach
                    </select>
                    @error('user_id')<div class="error">{{ $message }}</div>@enderror
                </div>
            </div>

            <div style="margin-bottom: 12px;">
                <label for="title" class="muted" style="display: block; margin-bottom: 6px;">Title</label>
                <input id="title" name="title" type="text" maxlength="120" required value="{{ old('title', $defaultTitle) }}">
                @error('title')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div style="margin-bottom: 12px;">
                <label for="body" class="muted" style="display: block; margin-bottom: 6px;">Body</label>
                <textarea id="body" name="body" maxlength="500" required>{{ old('body') }}</textarea>
                @error('body')<div class="error">{{ $message }}</div>@enderror
            </div>

            <div style="margin-bottom: 16px;">
                <label for="deep_link" class="muted" style="display: block; margin-bottom: 6px;">Deep link (optional)</label>
                <input id="deep_link" name="deep_link" type="text" maxlength="240" placeholder="result://read/<id>" value="{{ old('deep_link') }}">
                @error('deep_link')<div class="error">{{ $message }}</div>@enderror
            </div>

            <button type="submit">Send Push</button>
        </form>
    </div>
@endsection
