import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../domain/auth_models.dart';
import '../state/auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen(
      {super.key, required this.email, required this.initialChallenge});

  final String email;
  final OtpChallenge initialChallenge;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _digits = 5;

  late String _challengeId;
  late int _resendRemainingSeconds;
  Timer? _timer;

  final _controllers = List<TextEditingController>.generate(
      _digits, (_) => TextEditingController());
  final _focusNodes = List<FocusNode>.generate(_digits, (_) => FocusNode());

  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.initialChallenge.challengeId;
    _resendRemainingSeconds = widget.initialChallenge.resendAfterSeconds;
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    if (_resendRemainingSeconds <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendRemainingSeconds =
            (_resendRemainingSeconds - 1).clamp(0, 24 * 60 * 60);
      });
      if (_resendRemainingSeconds <= 0) {
        t.cancel();
      }
    });
  }

  String _code() => _controllers.map((c) => c.text.trim()).join();

  String _formatSeconds(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _setDigit(int index, String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\\D'), '');
    if (digitsOnly.isEmpty) {
      _controllers[index].text = '';
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    final char = digitsOnly.substring(digitsOnly.length - 1);
    _controllers[index].text = char;
    _controllers[index].selection =
        TextSelection.fromPosition(TextPosition(offset: char.length));

    if (index < _digits - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _verify() async {
    if (!mounted || _verifying) return;

    final code = _code();
    if (code.length != _digits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 5-digit code.')),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      final error = await auth.verifyOtp(
        email: widget.email,
        challengeId: _challengeId,
        code: code,
      );
      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }

      Navigator.of(context).popUntil((r) => r.isFirst);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (!mounted || _resending || _resendRemainingSeconds > 0) return;

    setState(() => _resending = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      final result = await auth.requestOtp(widget.email);
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
          const SnackBar(content: Text('Failed to resend OTP.')),
        );
        return;
      }

      _challengeId = challenge.challengeId;
      setState(() {
        _resendRemainingSeconds = challenge.resendAfterSeconds;
      });
      _startResendTimer();

      if (challenge.debugCode != null && challenge.debugCode!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DEV OTP: ${challenge.debugCode}')),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed:
                          _verifying ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: PalmTokens.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: PalmTokens.shadowSoft,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: PalmTokens.primaryDark,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Enter 5-Digit Code',
                    textAlign: TextAlign.center,
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a code to your email',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      color: PalmTokens.textSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: PalmTokens.textMain,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_digits, (i) {
                        return Padding(
                          padding:
                              EdgeInsets.only(right: i == _digits - 1 ? 0 : 10),
                          child: _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            enabled: !_verifying,
                            onChanged: (v) => _setDigit(i, v),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: _verifying ? null : _verify,
                    icon: _verifying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PalmTokens.neutralDark,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_verifying ? 'Verifying...' : 'Verify & Login'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Didn't receive the code?",
                          style: text.bodyMedium?.copyWith(
                            color: PalmTokens.textSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: (_resendRemainingSeconds > 0 ||
                                  _resending ||
                                  _verifying)
                              ? null
                              : _resend,
                          child: Text.rich(
                            TextSpan(
                              text: 'Resend Code',
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.underline,
                                decorationThickness: 2,
                                decorationColor:
                                    PalmTokens.primary.withValues(alpha: 0.35),
                                color:
                                    (_resendRemainingSeconds > 0 || _resending)
                                        ? PalmTokens.textSub
                                        : PalmTokens.textMain,
                              ),
                              children: [
                                if (_resendRemainingSeconds > 0) ...[
                                  TextSpan(
                                    text:
                                        '  (${_formatSeconds(_resendRemainingSeconds)})',
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: PalmTokens.primaryDark,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Need help? Contact Support',
                          style: text.bodySmall?.copyWith(
                            color: PalmTokens.textSub.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                PalmTokens.textSub.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 8),
                ],
              ),
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SizedBox(
      width: 58,
      height: 72,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        maxLength: 1,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.03),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: PalmTokens.primary, width: 2),
          ),
        ),
        onChanged: onChanged,
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
