import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../state/auth_controller.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email is required';
    if (!v.contains('@') || v.length < 5) return 'Enter a valid email';
    return null;
  }

  Future<void> _sendOtp() async {
    if (!mounted || _isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      final email = _emailController.text.trim();
      final result = await auth.requestOtp(email);
      if (!mounted) return;

      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!)),
        );
        return;
      }

      final challenge = result.challenge;
      if (challenge == null || challenge.challengeId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to request OTP.')),
        );
        return;
      }

      if (challenge.debugCode != null && challenge.debugCode!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEV OTP: ${challenge.debugCode}')),
        );
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: email, initialChallenge: challenge),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 56),
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color:
                                    PalmTokens.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: PalmTokens.shadowSoft,
                              ),
                              child: const Icon(
                                Icons.fingerprint,
                                color: PalmTokens.primaryDark,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Enter your email to sign in or create an account.',
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: PalmTokens.textSub,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 42),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Email Address',
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  validator: _validateEmail,
                                  enabled: !_isSubmitting,
                                  decoration: const InputDecoration(
                                    hintText: 'you@example.com',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                FilledButton.icon(
                                  onPressed: _isSubmitting ? null : _sendOtp,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: PalmTokens.neutralDark,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.mark_email_read_outlined),
                                  label: Text(
                                    _isSubmitting ? 'Sending...' : 'Send OTP',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20, horizontal: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18, top: 28),
                            child: Center(
                              child: Text(
                                'Need help? Contact Support',
                                style: text.bodySmall?.copyWith(
                                  color:
                                      PalmTokens.textSub.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: PalmTokens.textSub
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomGlowLine(),
          ),
        ],
      ),
    );
  }
}

class _BottomGlowLine extends StatelessWidget {
  const _BottomGlowLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              PalmTokens.primary.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  PalmTokens.background,
                  PalmTokens.background.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -220,
          right: -180,
          child: Container(
            width: 520,
            height: 520,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PalmTokens.primary.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          top: 280,
          left: -160,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PalmTokens.primary.withValues(alpha: 0.10),
            ),
          ),
        ),
      ],
    );
  }
}
