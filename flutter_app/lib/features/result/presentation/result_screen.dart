import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/state/capture_controller.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../data/palm_reads_api.dart';
import '../domain/palm_read_models.dart';

final palmReadDetailProvider =
    FutureProvider.family<PalmReadDetail, String>((ref, id) async {
  return ref.read(palmReadsApiProvider).getPalmRead(id);
});

final palmImageBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, id) async {
  return ref.read(palmReadsApiProvider).getImageBytes(id);
});

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.readId});

  final String readId;

  static const Map<String, String> _lineDisplayNames = {
    'life': 'Life line',
    'head': 'Head line',
    'heart': 'Heart line',
    'fate': 'Fate line',
    'sun': 'Sun (Apollo) line',
  };

  static const Map<String, String> _lineMeanings = {
    'life':
        'Usually interpreted around vitality, stamina, and how you manage energy over time.',
    'head':
        'Usually interpreted around thinking style, planning approach, and decision patterns.',
    'heart':
        'Usually interpreted around emotional expression, trust, and relationship style.',
    'fate':
        'Usually interpreted around direction, career structure, and long-term responsibilities.',
    'sun':
        'Usually interpreted around creativity, visibility, and satisfaction from recognition.',
  };

  String _sanitizeTitle(String raw) {
    var title = raw.trim();
    if (title.isEmpty) return title;

    // Some older builds appended a confidence label like "Needs review".
    title = title.replaceAll(
        RegExp(r'\\s*:\\s*needs\\s+review\\s*$', caseSensitive: false), '');
    title = title
        .replaceAll(RegExp(r'\\bneeds\\s+review\\b', caseSensitive: false), '')
        .trim();
    title = title.replaceAll(RegExp(r'\\s{2,}'), ' ').trim();
    title = title.replaceAll(RegExp(r'\\s+:\\s+$'), '').trim();

    return title;
  }

  String _displayNameForKey(String key, String fallbackTitle) {
    final k = key.trim().toLowerCase();
    return _lineDisplayNames[k] ?? _sanitizeTitle(fallbackTitle);
  }

  String _meaningForKey(String key) {
    final k = key.trim().toLowerCase();
    return _lineMeanings[k] ?? '';
  }

  String _buildNarrative(PalmReadDetail detail) {
    final apiNarrative = detail.readingText?.trim() ?? '';
    if (apiNarrative.isNotEmpty) {
      return apiNarrative;
    }

    final result = detail.resultJson;
    final resultNarrative = result?['narrative']?.toString().trim() ?? '';
    if (resultNarrative.isNotEmpty) {
      return resultNarrative;
    }

    return '-';
  }

  List<Map<String, dynamic>> _lineSituations(PalmReadDetail detail) {
    final result = detail.resultJson;
    final raw = result?['line_situations'];
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((entry) =>
            entry.map((key, value) => MapEntry(key.toString(), value)))
        .toList()
        .cast<Map<String, dynamic>>();
  }

  Future<void> _openFeedback(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeedbackSheet(palmReadId: readId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(palmReadDetailProvider(readId));
    final imageBytesAsync = ref.watch(palmImageBytesProvider(readId));
    final capture = ref.watch(captureControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Palm Reading Result'),
        actions: [
          IconButton(
            onPressed: () => _openFeedback(context),
            icon: const Icon(Icons.feedback_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(palmReadDetailProvider(readId));
          ref.invalidate(palmImageBytesProvider(readId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            detailAsync.when(
              data: (detail) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Result ID: ${detail.id}'),
                  Text(
                      'Hand signature hash: ${detail.handSignatureHash ?? '-'}'),
                  Text('Status: ${detail.status}'),
                  if (detail.processingMs != null)
                    Text('Processing: ${detail.processingMs} ms'),
                  const SizedBox(height: 12),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Result error: $err'),
            ),
            if (capture.imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  capture.imageFile!,
                  fit: BoxFit.cover,
                  height: 280,
                ),
              )
            else
              imageBytesAsync.when(
                data: (bytes) {
                  if (bytes == null || bytes.isEmpty) {
                    return Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Photo preview unavailable'),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      height: 280,
                    ),
                  );
                },
                loading: () => Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
                error: (_, __) => Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Photo preview unavailable'),
                ),
              ),
            const SizedBox(height: 12),
            detailAsync.when(
              data: (detail) {
                final narrative = _buildNarrative(detail);
                final result = detail.resultJson;
                final lineSituations = _lineSituations(detail);
                final disclaimer =
                    result?['disclaimer']?.toString().trim() ?? '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Line-by-line insights',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (lineSituations.isEmpty)
                      const Text(
                        'Line insights are not available yet for this result.',
                      )
                    else
                      ...lineSituations.map((entry) {
                        final key = entry['key']?.toString() ?? '';
                        final titleText = entry['title']?.toString() ?? '';
                        final title = _displayNameForKey(key, titleText);
                        final meaning = _meaningForKey(key);
                        final situation =
                            entry['situation']?.toString().trim() ??
                                'No additional details available.';
                        final prediction =
                            entry['prediction']?.toString().trim() ?? '';
                        final suggestion =
                            entry['suggestion']?.toString().trim() ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    text:
                                        meaning.isNotEmpty ? '$title: ' : title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                    children: meaning.isNotEmpty
                                        ? [
                                            TextSpan(
                                              text: meaning,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.normal,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ]
                                        : const [],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(situation),
                                if (prediction.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Likely direction: $prediction',
                                    style:
                                        const TextStyle(color: Colors.black87),
                                  ),
                                ],
                                if (suggestion.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Suggestion: $suggestion',
                                    style:
                                        const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    const Text(
                      'Reading narrative',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      narrative,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    if (disclaimer.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Note: $disclaimer',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
