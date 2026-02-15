import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../result/domain/palm_read_models.dart';
import '../../result/presentation/result_screen.dart';
import '../../result/state/palm_read_providers.dart';
import '../../upload/presentation/upload_progress_screen.dart';
import '../state/history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _HistoryFilter { all, completed, processing, failed }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_HistoryGroup> _groupItems(List<PalmReadDetail> items) {
    final now = DateTime.now();
    final monthFmt = DateFormat('MMMM');
    final monthYearFmt = DateFormat('MMMM yyyy');

    String labelFor(DateTime? dt) {
      if (dt == null) return 'Unknown';
      if (dt.year == now.year && dt.month == now.month) return 'This Month';
      if (dt.year == now.year) return monthFmt.format(dt);
      return monthYearFmt.format(dt);
    }

    final groups = <String, List<PalmReadDetail>>{};
    for (final item in items) {
      final createdAt = item.createdAt;
      final label = labelFor(createdAt);
      groups.putIfAbsent(label, () => []).add(item);
    }

    final orderedLabels = <String>[];
    if (groups.containsKey('This Month')) orderedLabels.add('This Month');
    final other =
        groups.keys.where((k) => k != 'This Month').toList(growable: false);
    orderedLabels.addAll(other);

    return [
      for (final label in orderedLabels)
        _HistoryGroup(label: label, items: groups[label] ?? const []),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(palmHistoryProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Text(
                    'History',
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      selected: _filter == _HistoryFilter.all,
                      label: 'All',
                      onTap: () => setState(() => _filter = _HistoryFilter.all),
                    ),
                    const SizedBox(width: 12),
                    _FilterPill(
                      selected: _filter == _HistoryFilter.completed,
                      label: 'Completed',
                      onTap: () =>
                          setState(() => _filter = _HistoryFilter.completed),
                    ),
                    const SizedBox(width: 12),
                    _FilterPill(
                      selected: _filter == _HistoryFilter.processing,
                      label: 'Processing',
                      onTap: () =>
                          setState(() => _filter = _HistoryFilter.processing),
                    ),
                    const SizedBox(width: 12),
                    _FilterPill(
                      selected: _filter == _HistoryFilter.failed,
                      label: 'Failed',
                      onTap: () =>
                          setState(() => _filter = _HistoryFilter.failed),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.refresh(palmHistoryProvider.future),
                child: historyAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, _) => ListView(
                    children: [
                      const SizedBox(height: 160),
                      Center(child: Text('Failed: $err')),
                    ],
                  ),
                  data: (page) {
                    final all = page.items;

                    List<PalmReadDetail> filtered() {
                      switch (_filter) {
                        case _HistoryFilter.completed:
                          return all
                              .where((e) => e.status == 'completed')
                              .toList();
                        case _HistoryFilter.failed:
                          return all
                              .where((e) => e.status == 'failed')
                              .toList();
                        case _HistoryFilter.processing:
                          return all
                              .where((e) =>
                                  e.status != 'completed' &&
                                  e.status != 'failed')
                              .toList();
                        case _HistoryFilter.all:
                          return all;
                      }
                    }

                    final items = filtered();
                    if (items.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                        children: [
                          Center(
                            child: Text(
                              'No readings yet.',
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: PalmTokens.textSub,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final groups = _groupItems(items);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      children: [
                        for (final group in groups) ...[
                          _SectionHeader(label: group.label),
                          const SizedBox(height: 10),
                          for (final item in group.items) ...[
                            _HistoryTile(item: item),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                        ],
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 30),
                            child: Text(
                              'Showing ${items.length} of ${page.total} readings',
                              style: text.bodySmall?.copyWith(
                                color:
                                    PalmTokens.textSub.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? PalmTokens.primary : PalmTokens.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.10),
          ),
          boxShadow: selected ? PalmTokens.shadowSoft : null,
        ),
        child: Text(
          label,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: selected ? PalmTokens.neutralDark : PalmTokens.textSub,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
        style: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: PalmTokens.textSub.withValues(alpha: 0.55),
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _HistoryGroup {
  const _HistoryGroup({required this.label, required this.items});

  final String label;
  final List<PalmReadDetail> items;
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.item});

  final PalmReadDetail item;

  String _title() {
    final dt = item.createdAt;
    if (dt == null) return 'Unknown date';
    return DateFormat('MMM dd, yyyy').format(dt.toLocal());
  }

  String _handText() {
    final h = item.handedness.toLowerCase();
    switch (h) {
      case 'left':
        return 'Left Hand';
      case 'right':
        return 'Right Hand';
      default:
        return 'Unknown';
    }
  }

  String _friendlyFailureReason(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final lower = trimmed.toLowerCase();
    if (lower.contains('hand_not_detected')) {
      return 'No hand detected';
    }
    if (lower.contains('palm_lines_not_detected')) {
      return "Couldn't detect palm lines";
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = item.status;
    final isCompleted = status == 'completed';
    final isFailed = status == 'failed';
    final isProcessing = !isCompleted && !isFailed;

    final badge = isCompleted
        ? _BadgeMeta('Completed', PalmTokens.success)
        : isFailed
            ? _BadgeMeta('Failed', PalmTokens.danger)
            : _BadgeMeta('Processing', PalmTokens.warning);

    final failureReason = _friendlyFailureReason(item.failureReason ?? '');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (isProcessing) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UploadProgressScreen(existingReadId: item.id),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResultScreen(readId: item.id)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: PalmTokens.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: PalmTokens.shadowCard,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: isCompleted
                          ? _Thumb(readId: item.id)
                          : Container(
                              color: (isFailed
                                      ? PalmTokens.danger
                                      : PalmTokens.warning)
                                  .withValues(alpha: 0.10),
                              child: Icon(
                                isFailed ? Icons.error_outline : Icons.sync,
                                color: isFailed
                                    ? PalmTokens.danger
                                    : PalmTokens.warning,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _title(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StatusBadge(meta: badge),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.pan_tool,
                                size: 16,
                                color:
                                    PalmTokens.textSub.withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isFailed && failureReason.isNotEmpty
                                    ? '${_handText()} • $failureReason'
                                    : _handText(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: PalmTokens.textSub,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right,
                      color: PalmTokens.textSub.withValues(alpha: 0.6)),
                ],
              ),
            ),
            if (isProcessing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: PalmTokens.warning.withValues(alpha: 0.25),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.65,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: PalmTokens.warning,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.readId});

  final String readId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(palmImageBytesProvider(readId));
    return bytesAsync.when(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return Container(color: Colors.black12);
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
      loading: () => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Container(color: Colors.black12),
    );
  }
}

class _BadgeMeta {
  const _BadgeMeta(this.label, this.color);

  final String label;
  final Color color;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.meta});

  final _BadgeMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        meta.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: meta.color,
            ),
      ),
    );
  }
}
