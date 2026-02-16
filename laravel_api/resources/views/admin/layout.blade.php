<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'PalmRead Admin' }}</title>
    <style>
        :root {
            --bg: #f3f5f4;
            --surface: #ffffff;
            --text: #0f172a;
            --muted: #64748b;
            --line: rgba(15, 23, 42, 0.1);
            --primary: #13eca4;
            --primary-dark: #0fb880;
            --danger: #ef4444;
            --warning: #f59e0b;
            --success: #10b981;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, sans-serif;
            color: var(--text);
            background: var(--bg);
        }
        .container {
            max-width: 1180px;
            margin: 0 auto;
            padding: 24px 18px 48px;
        }
        .topbar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            margin-bottom: 22px;
        }
        .brand {
            font-size: 28px;
            font-weight: 800;
            letter-spacing: -0.4px;
        }
        .nav {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .nav a {
            text-decoration: none;
            color: var(--muted);
            background: var(--surface);
            border: 1px solid var(--line);
            border-radius: 999px;
            padding: 8px 14px;
            font-size: 14px;
            font-weight: 600;
        }
        .nav a.active {
            color: #052d20;
            border-color: rgba(19, 236, 164, 0.5);
            background: rgba(19, 236, 164, 0.18);
        }
        .card {
            background: var(--surface);
            border: 1px solid var(--line);
            border-radius: 16px;
            padding: 16px;
        }
        .grid {
            display: grid;
            gap: 14px;
        }
        .grid.stats {
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        }
        .stat-title {
            color: var(--muted);
            font-size: 13px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }
        .stat-value {
            font-size: 30px;
            font-weight: 800;
            letter-spacing: -0.6px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            text-align: left;
            padding: 11px 10px;
            border-bottom: 1px solid var(--line);
            font-size: 14px;
            vertical-align: top;
        }
        th {
            color: var(--muted);
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .badge {
            display: inline-block;
            border-radius: 999px;
            padding: 4px 10px;
            font-size: 12px;
            font-weight: 700;
            line-height: 1.2;
        }
        .badge.completed { background: rgba(16, 185, 129, 0.14); color: var(--success); }
        .badge.processing, .badge.queued { background: rgba(245, 158, 11, 0.15); color: var(--warning); }
        .badge.failed { background: rgba(239, 68, 68, 0.14); color: var(--danger); }
        .muted { color: var(--muted); }
        .toolbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 10px;
            margin-bottom: 12px;
            flex-wrap: wrap;
        }
        input, select, textarea, button {
            border-radius: 10px;
            border: 1px solid var(--line);
            padding: 10px 12px;
            font: inherit;
            color: inherit;
            background: #fff;
        }
        textarea { min-height: 110px; resize: vertical; }
        button {
            cursor: pointer;
            border-color: transparent;
            background: var(--primary);
            color: #032218;
            font-weight: 700;
        }
        .ghost-btn {
            background: #fff;
            border-color: var(--line);
            color: var(--muted);
        }
        .flash {
            margin-bottom: 14px;
            padding: 10px 12px;
            border-radius: 10px;
            border: 1px solid rgba(16, 185, 129, 0.35);
            background: rgba(16, 185, 129, 0.1);
            color: #04664a;
            font-size: 14px;
            font-weight: 600;
        }
        .error {
            color: var(--danger);
            margin-top: 6px;
            font-size: 13px;
            font-weight: 600;
        }
        .pagination {
            margin-top: 14px;
        }
        .pagination nav {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }
        .pagination a, .pagination span {
            display: inline-block;
            border: 1px solid var(--line);
            border-radius: 8px;
            padding: 6px 10px;
            font-size: 13px;
            color: var(--muted);
            text-decoration: none;
            background: #fff;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="topbar">
        <div class="brand">PalmRead Admin</div>
        <div class="nav">
            <a href="{{ route('admin.dashboard') }}" class="{{ request()->routeIs('admin.dashboard') ? 'active' : '' }}">Dashboard</a>
            <a href="{{ route('admin.users') }}" class="{{ request()->routeIs('admin.users') ? 'active' : '' }}">Users</a>
            <a href="{{ route('admin.uploads') }}" class="{{ request()->routeIs('admin.uploads') ? 'active' : '' }}">Uploads</a>
            <a href="{{ route('admin.push') }}" class="{{ request()->routeIs('admin.push') ? 'active' : '' }}">Push</a>
        </div>
    </div>

    @if (session('status'))
        <div class="flash">{{ session('status') }}</div>
    @endif

    @yield('content')
</div>
</body>
</html>
