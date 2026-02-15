class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
  });

  final int id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AuthUser user;
  final String token;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
    );
  }
}

class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    this.debugCode,
  });

  final String challengeId;
  final int expiresInSeconds;
  final int resendAfterSeconds;
  final String? debugCode;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) {
    return OtpChallenge(
      challengeId: json['challenge_id']?.toString() ?? '',
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 0,
      resendAfterSeconds: (json['resend_after_seconds'] as num?)?.toInt() ?? 0,
      debugCode: json['debug_code']?.toString(),
    );
  }
}
