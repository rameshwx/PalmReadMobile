<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminBasicAuthMiddleware
{
    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $expectedUser = (string) config('admin.username', '');
        $expectedPass = (string) config('admin.password', '');

        if ($expectedUser === '' || $expectedPass === '') {
            abort(503, 'Admin credentials are not configured.');
        }

        $providedUser = (string) ($request->getUser() ?? '');
        $providedPass = (string) ($request->getPassword() ?? '');

        $ok = hash_equals($expectedUser, $providedUser) &&
            hash_equals($expectedPass, $providedPass);

        if (! $ok) {
            return response('Unauthorized', 401, [
                'WWW-Authenticate' => 'Basic realm="PalmRead Admin"',
            ]);
        }

        return $next($request);
    }
}
