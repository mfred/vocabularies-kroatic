import 'package:flutter/material.dart';

import '../models/duel.dart';
import '../../quiz/models/quiz_direction.dart';

/// Modal: zeigt den Inhalt einer eingehenden Challenge und gibt 'accept'
/// oder 'decline' zurück. Bei Abbruch null.
class DuelIncomingDialog extends StatelessWidget {
  const DuelIncomingDialog({super.key, required this.duel});

  final Duel duel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final direction = duel.direction == 'hr_de'
        ? QuizDirection.hrToDe
        : QuizDirection.deToHr;
    final challengerTime = (duel.challengerResult.totalMs / 1000)
        .toStringAsFixed(2);

    return AlertDialog(
      icon: const Text('⚔️', style: TextStyle(fontSize: 36)),
      title: Text('Duell von ${duel.challengerDisplayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  duel.lessonTitle,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.swap_horiz,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(direction.label, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: scheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zeit zu schlagen',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '$challengerTime s',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('decline'),
          child: const Text('Ablehnen'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop('accept'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Annehmen'),
        ),
      ],
    );
  }
}
