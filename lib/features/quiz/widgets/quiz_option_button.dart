import 'package:flutter/material.dart';

enum QuizOptionState { neutral, correct, wrong, dimmed }

class QuizOptionButton extends StatelessWidget {
  const QuizOptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final QuizOptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (border, bg, fg) = switch (state) {
      QuizOptionState.correct => (
          Colors.green.shade600,
          Colors.green.shade50,
          Colors.green.shade900,
        ),
      QuizOptionState.wrong => (
          Colors.red.shade600,
          Colors.red.shade50,
          Colors.red.shade900,
        ),
      QuizOptionState.dimmed => (
          scheme.outlineVariant,
          scheme.surfaceContainerLow,
          scheme.onSurfaceVariant,
        ),
      QuizOptionState.neutral => (
          scheme.outlineVariant,
          scheme.surface,
          scheme.onSurface,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.5),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (state == QuizOptionState.correct)
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                if (state == QuizOptionState.wrong)
                  Icon(Icons.cancel, color: Colors.red.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
