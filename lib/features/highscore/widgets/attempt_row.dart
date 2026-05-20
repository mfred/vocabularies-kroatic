import 'package:flutter/material.dart';

import '../../../core/widgets/speak_button.dart';
import '../../quiz/models/quiz_direction.dart';
import '../models/session_detail.dart';

class AttemptRow extends StatelessWidget {
  const AttemptRow({
    super.key,
    required this.attempt,
    required this.direction,
  });

  final AttemptDetail attempt;
  final QuizDirection? direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prompt = attempt.promptFor(direction);
    final answer = attempt.answerFor(direction);
    final secs = (attempt.responseMs / 1000).toStringAsFixed(1);

    final accent = attempt.wasCorrect ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                attempt.wasCorrect ? Icons.check_circle : Icons.cancel,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Frage ${attempt.questionOrder + 1}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (attempt.jokers.isNotEmpty)
                for (final j in attempt.jokers)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: j.label,
                      child: Text(j.emoji, style: const TextStyle(fontSize: 14)),
                    ),
                  )
              else if (attempt.hintUsed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.lightbulb,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                '$secs s',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prompt ?? '—',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  answer ?? '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (attempt.hrText != null && attempt.hrText!.isNotEmpty)
                SpeakButton(text: attempt.hrText!, langTag: 'hr-HR'),
            ],
          ),
          if (!attempt.wasCorrect &&
              attempt.pickedOption != null &&
              attempt.pickedOption != answer) ...[
            const SizedBox(height: 6),
            Text(
              'Gewählt: „${attempt.pickedOption}"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
