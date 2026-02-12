import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/session/session_expiry.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/capture/presentation/capture_screen.dart';
import 'features/history/presentation/history_screen.dart';

class PalmReadApp extends ConsumerWidget {
  const PalmReadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final sessionExpired = ref.watch(sessionExpiredProvider);

    return MaterialApp(
      title: 'PalmReadMobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A6B57)),
        useMaterial3: true,
      ),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (idx) => setState(() => _index = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined), label: 'Capture'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
      ),
    );
  }
}
