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

class PalmSurface extends StatelessWidget {
  const PalmSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = PalmTokens.radiusLg,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? PalmTokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: PalmTokens.shadowCard,
      ),
      child: child,
    );
  }
}

class PalmModalPanel extends StatelessWidget {
  const PalmModalPanel({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: desktop ? 24 : 0),
            decoration: BoxDecoration(
              color: PalmTokens.surface,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(28),
                bottom: desktop ? const Radius.circular(28) : Radius.zero,
              ),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: PalmTokens.shadowSoft,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class PalmModalOption extends StatelessWidget {
  const PalmModalOption({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PalmTokens.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: PalmTokens.primaryDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(
                          color: PalmTokens.textSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: PalmTokens.textSub.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showPalmSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (sheetContext) => PalmModalPanel(
      maxWidth: maxWidth,
      child: builder(sheetContext),
    ),
  );
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
