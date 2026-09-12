import 'package:flutter/material.dart';

import '../theme/palm_tokens.dart';

/// Keeps desktop content readable while allowing the existing mobile screens
/// to use the full width available to them.
class PalmPageContainer extends StatelessWidget {
  const PalmPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final horizontal =
            desktop ? (constraints.maxWidth * 0.035).clamp(28.0, 48.0) : 20.0;
        final resolvedPadding = padding ??
            EdgeInsets.fromLTRB(
                horizontal, desktop ? 28 : 18, horizontal, desktop ? 36 : 20);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(
              width: double.infinity,
              child: Padding(padding: resolvedPadding, child: child),
            ),
          ),
        );
      },
    );
  }
}

class PalmBrandMark extends StatelessWidget {
  const PalmBrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: PalmTokens.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
          child: Icon(
            Icons.psychology,
            size: compact ? 20 : 24,
            color: PalmTokens.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'PalmRead',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? text.titleMedium : text.titleLarge)?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class PalmSectionIntro extends StatelessWidget {
  const PalmSectionIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: text.labelMedium?.copyWith(
            color: PalmTokens.primaryDark,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: text.bodyLarge?.copyWith(
              color: PalmTokens.textSub,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
