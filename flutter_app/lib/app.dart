import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/session/session_expiry.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/capture/presentation/capture_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'shared/theme/palm_theme.dart';
import 'shared/theme/palm_tokens.dart';

class PalmReadApp extends ConsumerWidget {
  const PalmReadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final sessionExpired = ref.watch(sessionExpiredProvider);

    return MaterialApp(
      title: 'PalmReadMobile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: PalmTheme.light(),
      home: sessionExpired
          ? const LoginScreen()
          : auth.when(
              data: (state) => state.isAuthenticated
                  ? const _HomeShell()
                  : const LoginScreen(),
              loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator())),
              error: (_, __) => const LoginScreen(),
            ),
    );
  }
}

class _HomeShell extends ConsumerStatefulWidget {
  const _HomeShell();

  @override
  ConsumerState<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const CaptureScreen(), const HistoryScreen()];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: _BottomNavBar(
        index: _index,
        onSelect: (idx) => setState(() => _index = idx),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PalmTokens.surface,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  selected: index == 0,
                  label: 'Capture',
                  icon: Icons.filter_center_focus,
                  onTap: () => onSelect(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  selected: index == 1,
                  label: 'History',
                  icon: Icons.history,
                  onTap: () => onSelect(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PalmTokens.primaryDark : PalmTokens.textSub;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: color,
        );

    return InkWell(
      borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 4,
              width: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? PalmTokens.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? PalmTokens.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
