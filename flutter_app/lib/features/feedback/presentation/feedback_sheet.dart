import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../../result/data/palm_reads_api.dart';

class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({
    super.key,
    required this.palmReadId,
    this.title = 'Was this accurate?',
    this.initialIsCorrect,
  });

  final String palmReadId;
  final String title;
  final bool? initialIsCorrect;

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  bool? _isCorrect;
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _isCorrect = widget.initialIsCorrect;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isCorrect == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose yes or no.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(palmReadsApiProvider).submitFeedback(
            palmReadId: widget.palmReadId,
            isCorrect: _isCorrect!,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feedback failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'A quick note helps us improve future readings.',
            style: text.bodyMedium?.copyWith(
              color: PalmTokens.textSub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FeedbackChoice(
                  label: 'Yes',
                  icon: Icons.thumb_up_alt_outlined,
                  selected: _isCorrect == true,
                  onTap: () => setState(() => _isCorrect = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FeedbackChoice(
                  label: 'Not quite',
                  icon: Icons.thumb_down_alt_outlined,
                  selected: _isCorrect == false,
                  onTap: () => setState(() => _isCorrect = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              hintText: 'Tell us what looked wrong or right',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PalmTokens.neutralDark,
                    ),
                  )
                : const Text('Submit feedback'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackChoice extends StatelessWidget {
  const _FeedbackChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected
            ? PalmTokens.primary.withValues(alpha: 0.16)
            : PalmTokens.background,
        borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        border: Border.all(
          color: selected
              ? PalmTokens.primaryDark.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color:
                      selected ? PalmTokens.primaryDark : PalmTokens.textSub),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color:
                            selected ? PalmTokens.textMain : PalmTokens.textSub,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
