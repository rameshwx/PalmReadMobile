import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../result/presentation/result_screen.dart';
import '../state/history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(palmHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis History')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(palmHistoryProvider.future),
        child: history.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 180),
                  Center(child: Text('No analyses yet.')),
                ],
              );
            }

            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(
                      'Result ${item.id.substring(0, item.id.length > 8 ? 8 : item.id.length)}'),
                  subtitle: Text(
                    'Status: ${item.status} • Handedness: ${item.handedness} '
                    '• ${item.createdAt?.toLocal().toString() ?? ''}',
                  ),
                  trailing: item.handSignatureHash == null
                      ? null
                      : const Icon(Icons.check_circle_outline, size: 18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ResultScreen(readId: item.id)),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Failed: $err')),
        ),
      ),
    );
  }
}
