import 'package:flutter/material.dart';

import '../services/daily_assignment.dart';

/// Pop-up vor dem Start des Quiz des Tages — zeigt heutigen Mode + Bonus.
/// Liefert `true` bei „Los geht's", `false` bei „Später" / Dismiss.
Future<bool> showDailyAssignmentDialog(
  BuildContext context, {
  required DailyAssignment assignment,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _DailyAssignmentDialog(assignment: assignment),
  );
  return result ?? false;
}

class _DailyAssignmentDialog extends StatelessWidget {
  const _DailyAssignmentDialog({required this.assignment});

  final DailyAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final modeTitle = assignment.mode == DailyMode.category &&
            assignment.categoryLessonTitleDe != null
        ? 'Quiz aus „${assignment.categoryLessonTitleDe}"'
        : assignment.mode.shortLabel;

    return AlertDialog(
      title: const Text('Quiz des Tages'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Block(
            color: scheme.primaryContainer,
            onColor: scheme.onPrimaryContainer,
            emoji: assignment.mode.emoji,
            title: modeTitle,
            description: assignment.mode.description,
          ),
          const SizedBox(height: 12),
          _Block(
            color: scheme.tertiaryContainer,
            onColor: scheme.onTertiaryContainer,
            emoji: assignment.bonus.emoji,
            title: assignment.bonus.shortLabel,
            description: assignment.bonus.description,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Später'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Los geht\'s'),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.color,
    required this.onColor,
    required this.emoji,
    required this.title,
    required this.description,
  });

  final Color color;
  final Color onColor;
  final String emoji;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
