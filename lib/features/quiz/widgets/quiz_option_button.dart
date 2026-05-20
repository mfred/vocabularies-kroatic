import 'package:flutter/material.dart';

enum QuizOptionState { neutral, correct, wrong, dimmed, eliminated }

class QuizOptionButton extends StatelessWidget {
  const QuizOptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.onSpeak,
  });

  final String label;
  final QuizOptionState state;
  final VoidCallback? onTap;

  /// Optionaler Lautsprecher-Callback. Wird nur im neutralen State
  /// angezeigt — sobald eine Antwort feststeht, verschwindet das Icon.
  final VoidCallback? onSpeak;

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
      QuizOptionState.eliminated => (
          scheme.outlineVariant.withValues(alpha: 0.35),
          scheme.surfaceContainerLowest,
          scheme.outline.withValues(alpha: 0.55),
        ),
      QuizOptionState.neutral => (
          scheme.outlineVariant,
          scheme.surface,
          scheme.onSurface,
        ),
    };
    final isEliminated = state == QuizOptionState.eliminated;
    final showSpeaker =
        state == QuizOptionState.neutral && onSpeak != null;

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
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      decoration: isEliminated
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: fg,
                      decorationThickness: 2,
                    ),
                  ),
                ),
                if (showSpeaker)
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: 'Vorlesen',
                    color: scheme.primary,
                    splashRadius: 22,
                    onPressed: onSpeak,
                  ),
                if (state == QuizOptionState.correct)
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                if (state == QuizOptionState.wrong)
                  Icon(Icons.cancel, color: Colors.red.shade700),
                if (isEliminated)
                  Icon(Icons.close, color: fg, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
