import 'package:flutter/material.dart';

class QuizHintPanel extends StatelessWidget {
  const QuizHintPanel({
    super.key,
    required this.hint,
    required this.isNew,
    required this.revealed,
    required this.onReveal,
  });

  final String hint;
  final bool isNew;
  final bool revealed;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (revealed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.tertiary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb, color: scheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onReveal,
      icon: const Icon(Icons.lightbulb_outline),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Hinweis anzeigen'),
          if (isNew) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.tertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'NEU',
                style: TextStyle(
                  color: scheme.onTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
