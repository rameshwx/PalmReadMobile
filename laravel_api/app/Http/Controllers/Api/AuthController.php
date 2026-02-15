<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\OtpCodeMail;
use App\Models\EmailOtp;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $email = $this->normalizeEmail($data['email']);
        if ($this->emailExistsInsensitive($email)) {
            throw ValidationException::withMessages([
                'email' => ['The email has already been taken.'],
            ]);
        }

        $user = User::query()->create([
            'name' => trim((string) $data['name']),
            'email' => $email,
            'password' => Hash::make($data['password']),
        ]);

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
            'token' => $token,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $email = $this->normalizeEmail($data['email']);
        $user = User::query()
            ->whereRaw('LOWER(email) = ?', [$email])
            ->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are invalid.'],
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
            'token' => $token,
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $email = $this->normalizeEmail($data['email']);

        try {
            Password::sendResetLink(['email' => $email]);
        } catch (\Throwable $exception) {
            report($exception);
        }

        return response()->json([
            'message' => 'If an account exists for this email, a password reset link has been sent.',
        ]);
    }

    public function requestOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $email = $this->normalizeEmail($data['email']);

        $ttlSeconds = max(60, (int) config('palm.otp_ttl_seconds', 600));
        $resendAfterSeconds = max(0, (int) config('palm.otp_resend_after_seconds', 45));
        $maxAttempts = max(1, (int) config('palm.otp_max_attempts', 5));

        $now = now();
        $last = EmailOtp::query()
            ->where('email', $email)
            ->orderByDesc('created_at')
            ->first();

        if ($last && $last->resend_available_at && $last->resend_available_at->isFuture()) {
            return response()->json([
                'message' => 'Please wait before requesting another code.',
                'resend_after_seconds' => $last->resend_available_at->diffInSeconds($now),
            ], 429);
        }

        $code = str_pad((string) random_int(0, 99999), 5, '0', STR_PAD_LEFT);

        $challenge = EmailOtp::query()->create([
            'email' => $email,
            'code_hash' => Hash::make($code),
            'expires_at' => $now->copy()->addSeconds($ttlSeconds),
            'resend_available_at' => $now->copy()->addSeconds($resendAfterSeconds),
            'attempts' => 0,
            'max_attempts' => $maxAttempts,
        ]);

        try {
            Mail::to($email)->send(new OtpCodeMail($code, $challenge->expires_at));
        } catch (\Throwable $exception) {
            report($exception);
        }

        $payload = [
            'challenge_id' => $challenge->id,
            'expires_in_seconds' => $ttlSeconds,
            'resend_after_seconds' => $resendAfterSeconds,
        ];

        $debug = filter_var(config('palm.otp_debug_echo', false), FILTER_VALIDATE_BOOL);
        if ($debug && app()->environment(['local', 'testing'])) {
            $payload['debug_code'] = $code;
        }

        return response()->json($payload);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'challenge_id' => ['required', 'string'],
            'code' => ['required', 'digits:5'],
        ]);

        $email = $this->normalizeEmail($data['email']);

        /** @var EmailOtp|null $otp */
        $otp = EmailOtp::query()
            ->where('id', $data['challenge_id'])
            ->where('email', $email)
            ->first();

        if (! $otp) {
            return response()->json([
                'message' => 'Invalid code.',
            ], 422);
        }

        if ($otp->consumed_at) {
            return response()->json([
                'message' => 'Code already used.',
            ], 422);
        }

        if ($otp->expires_at && $otp->expires_at->isPast()) {
            return response()->json([
                'message' => 'Code expired.',
            ], 422);
        }

        if ($otp->attempts >= $otp->max_attempts) {
            return response()->json([
                'message' => 'Too many attempts. Please request a new code.',
            ], 422);
        }

        if (! Hash::check($data['code'], $otp->code_hash)) {
            $otp->attempts = (int) $otp->attempts + 1;
            $otp->save();

            return response()->json([
                'message' => 'Invalid code.',
            ], 422);
        }

        $otp->consumed_at = now();
        $otp->save();

        $user = User::query()
            ->whereRaw('LOWER(email) = ?', [$email])
            ->first();

        if (! $user) {
            $local = Str::before($email, '@');
            $local = preg_replace('/[._-]+/', ' ', $local) ?: $local;
            $name = trim((string) $local);
            $name = $name !== '' ? Str::title($name) : 'User';

            $user = User::query()->create([
                'name' => $name,
                'email' => $email,
                'password' => Hash::make(Str::random(40)),
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
            ],
            'token' => $token,
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $email = $this->normalizeEmail($data['email']);

        $status = Password::reset(
            [
                'email' => $email,
                'password' => $data['password'],
                'password_confirmation' => $data['password_confirmation'],
                'token' => $data['token'],
            ],
            function (User $user, string $password): void {
                $user->forceFill([
                    'password' => Hash::make($password),
                    'remember_token' => Str::random(60),
                ])->save();

                $user->tokens()->delete();

                event(new PasswordReset($user));
            }
        );

        if ($status !== Password::PASSWORD_RESET) {
            return response()->json([
                'message' => __($status),
            ], 422);
        }

        return response()->json([
            'message' => 'Password has been reset successfully.',
        ]);
    }

    private function normalizeEmail(string $email): string
    {
        return mb_strtolower(trim($email));
    }

    private function emailExistsInsensitive(string $normalizedEmail): bool
    {
        return User::query()
            ->whereRaw('LOWER(email) = ?', [$normalizedEmail])
            ->exists();
    }
}
