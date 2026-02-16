import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../data/palm_reads_api.dart';
import '../domain/palm_read_models.dart';
import '../state/palm_read_providers.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.readId});

  final String readId;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _sharing = false;

  List<Map<String, dynamic>> _lineSituations(PalmReadDetail detail) {
    final result = detail.resultJson;
    final raw = result?['line_situations'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((entry) =>
            entry.map((key, value) => MapEntry(key.toString(), value)))
        .toList()
        .cast<Map<String, dynamic>>();
  }

  String _narrative(PalmReadDetail detail) {
    final apiNarrative = detail.readingText?.trim() ?? '';
    if (apiNarrative.isNotEmpty) return apiNarrative;

    final result = detail.resultJson;
    final resultNarrative = result?['narrative']?.toString().trim() ?? '';
    if (resultNarrative.isNotEmpty) return resultNarrative;

    return '-';
  }

  String _pickPrediction(List<Map<String, dynamic>> situations) {
    String? fromKey(String key) {
      final entry = situations
          .where((e) => (e['key']?.toString() ?? '').toLowerCase() == key)
          .cast<Map<String, dynamic>>()
          .firstOrNull;
      final p = entry?['prediction']?.toString().trim();
      return (p == null || p.isEmpty) ? null : p;
    }

    return fromKey('fate') ??
        situations
            .map((e) => e['prediction']?.toString().trim() ?? '')
            .firstWhere((t) => t.isNotEmpty, orElse: () => '—');
  }

  String _pickSuggestion(
      PalmReadDetail detail, List<Map<String, dynamic>> situations) {
    final suggestions = detail.resultJson?['suggestions'];
    if (suggestions is List) {
      final first =
          suggestions.whereType<String>().map((s) => s.trim()).firstOrNull;
      if (first != null && first.isNotEmpty) return first;
    }

    String? fromKey(String key) {
      final entry = situations
          .where((e) => (e['key']?.toString() ?? '').toLowerCase() == key)
          .cast<Map<String, dynamic>>()
          .firstOrNull;
      final s = entry?['suggestion']?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return fromKey('head') ??
        situations
            .map((e) => e['suggestion']?.toString().trim() ?? '')
            .firstWhere((t) => t.isNotEmpty, orElse: () => '—');
  }

  Future<void> _submitThumb(bool isCorrect) async {
    try {
      await ref.read(palmReadsApiProvider).submitFeedback(
            palmReadId: widget.readId,
            isCorrect: isCorrect,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for the feedback.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feedback failed: $e')),
      );
    }
  }

  Future<void> _openFeedbackSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeedbackSheet(
        palmReadId: widget.readId,
        title: 'Was this accurate?',
        initialIsCorrect: false,
      ),
    );
  }

  Future<void> _shareText(PalmReadDetail detail) async {
    final situations = _lineSituations(detail);
    final direction = _pickPrediction(situations);
    final suggestion = _pickSuggestion(detail, situations);
    final narrative = _narrative(detail);

    final text = [
      'PalmRead Analysis',
      '',
      'Likely Direction: $direction',
      'Suggestion: $suggestion',
      '',
      narrative,
    ].join('\n');

    await Share.share(text);
  }

  Future<void> _shareSummaryImage(PalmReadDetail detail) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final situations = _lineSituations(detail);
      final direction = _pickPrediction(situations);
      final suggestion = _pickSuggestion(detail, situations);
      final narrative = _narrative(detail);

      final pngBytes = await _renderSummaryPng(
        readId: widget.readId,
        createdAt: detail.createdAt?.toLocal(),
        direction: direction,
        suggestion: suggestion,
        narrative: narrative,
      );

      await Share.shareXFiles(
        [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: 'palmread_${widget.readId}.png',
          ),
        ],
        text: 'PalmRead Analysis',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<Uint8List> _renderSummaryPng({
    required String readId,
    required DateTime? createdAt,
    required String direction,
    required String suggestion,
    required String narrative,
  }) async {
    const w = 1080;
    const h = 1350;
    const pad = 72.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    final size = Size(w.toDouble(), h.toDouble());

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          PalmTokens.background,
          PalmTokens.background.withValues(alpha: 0.92),
        ],
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    final accentA = Paint()..color = PalmTokens.primary.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.14),
      240,
      accentA,
    );
    final accentB = Paint()..color = PalmTokens.primary.withValues(alpha: 0.06);
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.52),
      280,
      accentB,
    );

    final dotPaint = Paint()
      ..color = PalmTokens.primary.withValues(alpha: 0.05);
    for (var y = 0; y < h; y += 34) {
      for (var x = 0; x < w; x += 34) {
        if (((x + y) ~/ 34) % 3 == 0) {
          canvas.drawCircle(
            Offset(x.toDouble() + 6, y.toDouble() + 8),
            1.2,
            dotPaint,
          );
        }
      }
    }

    final cardRect = Rect.fromLTWH(
      pad,
      190,
      size.width - (pad * 2),
      size.height - 380,
    );
    final card = RRect.fromRectAndRadius(cardRect, const Radius.circular(56));
    final cardPath = Path()..addRRect(card);
    canvas.drawShadow(cardPath, const Color(0x22000000), 18, false);
    canvas.drawRRect(card, Paint()..color = PalmTokens.surface);
    canvas.drawRRect(
      card,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    var cursorY = cardRect.top + 54;

    final badgeRect = Rect.fromLTWH(cardRect.left + 38, cursorY, 104, 104);
    final badgeR =
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(30));
    final badgePath = Path()..addRRect(badgeR);
    canvas.drawShadow(
      badgePath,
      PalmTokens.primary.withValues(alpha: 0.18),
      16,
      false,
    );
    canvas.drawRRect(
      badgeR,
      Paint()..color = PalmTokens.primary.withValues(alpha: 0.12),
    );
    _paintIcon(
      canvas,
      icon: Icons.fingerprint,
      rect: badgeRect,
      color: PalmTokens.primaryDark,
      size: 62,
    );

    final headerX = badgeRect.right + 26;
    final headerW = cardRect.right - headerX - 38;

    _paintText(
      canvas,
      text: 'PalmRead',
      offset: Offset(headerX, cursorY + 10),
      maxWidth: headerW,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        color: PalmTokens.textMain,
        letterSpacing: -0.2,
      ),
    );

    final titleY = cursorY + 54;
    _paintText(
      canvas,
      text: 'Your Analysis',
      offset: Offset(headerX, titleY),
      maxWidth: headerW,
      style: TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        color: PalmTokens.textMain.withValues(alpha: 0.96),
        letterSpacing: -1.0,
      ),
      maxLines: 1,
      ellipsis: '…',
    );

    cursorY += 150;

    final boxGap = 24.0;
    final boxW = (cardRect.width - 76 - boxGap) / 2.0;
    const boxH = 200.0;
    final boxY = cursorY;

    _paintSummaryBox(
      canvas,
      rect: Rect.fromLTWH(cardRect.left + 38, boxY, boxW, boxH),
      title: 'Likely Direction',
      value: direction,
      icon: Icons.explore,
      tint: PalmTokens.surface,
      border: Colors.black.withValues(alpha: 0.06),
    );

    _paintSummaryBox(
      canvas,
      rect: Rect.fromLTWH(
        cardRect.left + 38 + boxW + boxGap,
        boxY,
        boxW,
        boxH,
      ),
      title: 'Suggestion',
      value: suggestion,
      icon: Icons.tips_and_updates,
      tint: PalmTokens.primary.withValues(alpha: 0.10),
      border: PalmTokens.primary.withValues(alpha: 0.18),
    );

    cursorY += boxH + 46;

    final snippet = _snippet(narrative, maxChars: 380);
    _paintText(
      canvas,
      text: 'Overall Narrative',
      offset: Offset(cardRect.left + 38, cursorY),
      maxWidth: cardRect.width - 76,
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: PalmTokens.textMain,
        letterSpacing: -0.2,
      ),
      maxLines: 1,
      ellipsis: '…',
    );
    cursorY += 46;

    _paintText(
      canvas,
      text: snippet,
      offset: Offset(cardRect.left + 38, cursorY),
      maxWidth: cardRect.width - 76,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: PalmTokens.textSub.withValues(alpha: 0.92),
        height: 1.35,
      ),
      maxLines: 8,
      ellipsis: '…',
    );

    final idShort = readId.trim().isEmpty
        ? '—'
        : '#${readId.substring(0, readId.length < 5 ? readId.length : 5).toUpperCase()}';
    final dateText =
        createdAt == null ? null : DateFormat('MMM d, yyyy').format(createdAt);
    final footer =
        dateText == null ? 'ID: $idShort' : 'ID: $idShort  •  $dateText';

    _paintText(
      canvas,
      text: footer,
      offset: Offset(pad, size.height - 140),
      maxWidth: size.width - (pad * 2),
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: PalmTokens.textSub.withValues(alpha: 0.75),
        letterSpacing: 0.2,
      ),
      maxLines: 1,
      ellipsis: '…',
    );

    _paintText(
      canvas,
      text: 'Interpretive guidance, not guaranteed prediction.',
      offset: Offset(pad, size.height - 106),
      maxWidth: size.width - (pad * 2),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: PalmTokens.textSub.withValues(alpha: 0.55),
      ),
      maxLines: 1,
      ellipsis: '…',
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode PNG.');
    }
    return byteData.buffer.asUint8List();
  }

  static String _snippet(String text, {required int maxChars}) {
    final normalized = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 1).trimRight()}…';
  }

  static void _paintSummaryBox(
    Canvas canvas, {
    required Rect rect,
    required String title,
    required String value,
    required IconData icon,
    required Color tint,
    required Color border,
  }) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(34));
    final path = Path()..addRRect(r);
    canvas.drawShadow(path, const Color(0x12000000), 12, false);
    canvas.drawRRect(r, Paint()..color = tint);
    canvas.drawRRect(
      r,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: PalmTokens.textSub.withValues(alpha: 0.75),
      letterSpacing: 1.1,
    );
    final valueStyle = const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      color: PalmTokens.textMain,
      letterSpacing: -0.2,
    );

    _paintText(
      canvas,
      text: title.toUpperCase(),
      offset: Offset(rect.left + 22, rect.top + 22),
      maxWidth: rect.width - 64,
      style: titleStyle,
      maxLines: 1,
      ellipsis: '…',
    );

    _paintText(
      canvas,
      text: value,
      offset: Offset(rect.left + 22, rect.top + 92),
      maxWidth: rect.width - 64,
      style: valueStyle,
      maxLines: 2,
      ellipsis: '…',
    );

    _paintIcon(
      canvas,
      icon: icon,
      rect: Rect.fromLTWH(rect.right - 72, rect.top + 10, 56, 56),
      color: PalmTokens.textMain.withValues(alpha: 0.08),
      size: 56,
    );

    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left + 22, rect.bottom - 26, 64, 8),
      const Radius.circular(999),
    );
    canvas.drawRRect(bar, Paint()..color = PalmTokens.primary);
  }

  static void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required double maxWidth,
    required TextStyle style,
    int? maxLines,
    String? ellipsis,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: ellipsis,
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, offset);
  }

  static void _paintIcon(
    Canvas canvas, {
    required IconData icon,
    required Rect rect,
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final dx = rect.left + ((rect.width - painter.width) / 2.0);
    final dy = rect.top + ((rect.height - painter.height) / 2.0);
    painter.paint(canvas, Offset(dx, dy));
  }

  Future<void> _openShareSheet(PalmReadDetail detail) async {
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
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: const Text('Share Text'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _shareText(detail);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Share Summary Image'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _shareSummaryImage(detail);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(palmReadDetailProvider(widget.readId));
    final imageBytesAsync = ref.watch(palmImageBytesProvider(widget.readId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Analysis'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          detailAsync.when(
            data: (detail) => IconButton(
              onPressed: _sharing ? null : () => _openShareSheet(detail),
              icon: const Icon(Icons.share),
            ),
            loading: () => IconButton(
              onPressed: null,
              icon: const Icon(Icons.share),
            ),
            error: (_, __) => IconButton(
              onPressed: null,
              icon: const Icon(Icons.share),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(palmReadDetailProvider(widget.readId));
              ref.invalidate(palmImageBytesProvider(widget.readId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: PalmTokens.surface,
                    borderRadius: BorderRadius.circular(PalmTokens.radiusXl),
                    boxShadow: PalmTokens.shadowSoft,
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: imageBytesAsync.when(
                        data: (bytes) {
                          if (bytes == null || bytes.isEmpty) {
                            return Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Text('Photo unavailable'),
                            );
                          }
                          return Image.memory(bytes, fit: BoxFit.cover);
                        },
                        loading: () => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                        error: (_, __) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('Photo unavailable'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                detailAsync.when(
                  data: (detail) {
                    final situations = _lineSituations(detail);
                    final direction = _pickPrediction(situations);
                    final suggestion = _pickSuggestion(detail, situations);

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 430;
                        if (compact) {
                          return Column(
                            children: [
                              _SummaryCard(
                                title: 'Likely Direction',
                                value: direction,
                                icon: Icons.explore,
                                tint: PalmTokens.surface,
                              ),
                              const SizedBox(height: 12),
                              _SummaryCard(
                                title: 'Suggestion',
                                value: suggestion,
                                icon: Icons.tips_and_updates,
                                tint: PalmTokens.primary.withValues(alpha: 0.10),
                                border: PalmTokens.primary.withValues(alpha: 0.18),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                title: 'Likely Direction',
                                value: direction,
                                icon: Icons.explore,
                                tint: PalmTokens.surface,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCard(
                                title: 'Suggestion',
                                value: suggestion,
                                icon: Icons.tips_and_updates,
                                tint: PalmTokens.primary.withValues(alpha: 0.10),
                                border: PalmTokens.primary.withValues(alpha: 0.18),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 26),
                Text(
                  'Detailed Analysis',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                detailAsync.when(
                  data: (detail) {
                    final situations = _lineSituations(detail);
                    if (situations.isEmpty) {
                      return Text(
                        'Line analysis is not available yet for this reading.',
                        style: text.bodyMedium?.copyWith(
                          color: PalmTokens.textSub,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final meta in _LineMeta.all) ...[
                          _LineAccordion(
                            meta: meta,
                            initiallyOpen: meta.key == 'life',
                            situation: situations
                                .where((e) =>
                                    (e['key']?.toString() ?? '')
                                        .toLowerCase() ==
                                    meta.key)
                                .cast<Map<String, dynamic>>()
                                .firstOrNull,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                detailAsync.when(
                  data: (detail) {
                    final narrative = _narrative(detail);
                    return _NarrativeCard(
                      narrative: narrative,
                      onThumbUp: () => _submitThumb(true),
                      onThumbDown: () => _openFeedbackSheet(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PalmTokens.background.withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: detailAsync.when(
                    data: (detail) => FilledButton.icon(
                      onPressed:
                          _sharing ? null : () => _openShareSheet(detail),
                      icon: const Icon(Icons.ios_share),
                      label: Text(_sharing ? 'Sharing...' : 'Share Analysis'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineMeta {
  const _LineMeta(this.key, this.label, this.color, this.icon);

  final String key;
  final String label;
  final Color color;
  final IconData icon;

  static const all = [
    _LineMeta('life', 'Life', PalmTokens.danger, Icons.favorite),
    _LineMeta('head', 'Head', PalmTokens.info, Icons.psychology),
    _LineMeta('heart', 'Heart', PalmTokens.success, Icons.monitor_heart),
    _LineMeta('fate', 'Fate', PalmTokens.warning, Icons.auto_graph),
    _LineMeta('sun', 'Sun', PalmTokens.purple, Icons.wb_sunny_outlined),
  ];
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    this.border,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border ?? Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: PalmTokens.shadowCard,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -4,
            right: -2,
            child: Icon(icon,
                size: 44, color: PalmTokens.textMain.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: PalmTokens.textSub.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                softWrap: true,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: PalmTokens.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineAccordion extends StatefulWidget {
  const _LineAccordion({
    required this.meta,
    required this.situation,
    required this.initiallyOpen,
  });

  final _LineMeta meta;
  final Map<String, dynamic>? situation;
  final bool initiallyOpen;

  @override
  State<_LineAccordion> createState() => _LineAccordionState();
}

class _LineAccordionState extends State<_LineAccordion> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = widget.situation ?? const {};
    final situation = s['situation']?.toString().trim() ?? '—';
    final prediction = s['prediction']?.toString().trim() ?? '';
    final suggestion = s['suggestion']?.toString().trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: PalmTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: PalmTokens.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Container(
                padding: const EdgeInsets.all(14),
                color: Colors.black.withValues(alpha: 0.02),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.meta.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.meta.icon,
                          size: 18, color: widget.meta.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${widget.meta.label} Line Analysis',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: PalmTokens.textMain,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: Icon(Icons.expand_more,
                          color: PalmTokens.textSub.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      situation,
                      style: text.bodyMedium?.copyWith(
                        color: PalmTokens.textSub,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (prediction.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Likely direction: $prediction',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (suggestion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Suggestion: $suggestion',
                        style: text.bodyMedium?.copyWith(
                          color: PalmTokens.textSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({
    required this.narrative,
    required this.onThumbUp,
    required this.onThumbDown,
  });

  final String narrative;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: PalmTokens.shadowCard,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: PalmTokens.primary),
              const SizedBox(width: 10),
              Text(
                'Overall Narrative',
                style: text.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            narrative,
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Was this accurate?',
                style: text.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onThumbUp,
                icon: Icon(Icons.thumb_up,
                    size: 20, color: Colors.white.withValues(alpha: 0.60)),
              ),
              IconButton(
                onPressed: onThumbDown,
                icon: Icon(Icons.thumb_down,
                    size: 20, color: Colors.white.withValues(alpha: 0.60)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
