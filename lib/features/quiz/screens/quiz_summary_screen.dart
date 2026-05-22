import 'package:flutter/material.dart';

import '../../../shared/widgets/tablet_constrained.dart';
import '../models/quiz_direction.dart';

class QuizSummaryScreen extends StatelessWidget {
  const QuizSummaryScreen({
    super.key,
    required this.lessonTitle,
    required this.direction,
    required this.correctCount,
    required this.totalCount,
    required this.durationSeconds,
    required this.hintsUsed,
    required this.score,
    required this.onRetry,
    required this.onBack,
  });

  final String lessonTitle;
  final QuizDirection direction;
  final int correctCount;
  final int totalCount;
  final int durationSeconds;
  final int hintsUsed;
  final int score;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent =
        totalCount == 0 ? 0 : ((correctCount / totalCount) * 100).round();
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('Zusammenfassung · ${direction.compactLabel}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onBack,
        ),
      ),
      body: TabletConstrained(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lessonTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              percent >= 80
                  ? 'Stark! 🎉'
                  : percent >= 50
                      ? 'Solide.'
                      : 'Weiter üben!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _BigStat(
              label: 'Richtig',
              value: '$correctCount / $totalCount',
              accent: percent >= 50 ? Colors.green : Colors.orange,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _BigStat(
              label: 'Trefferquote',
              value: '$percent %',
              accent: scheme.primary,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _BigStat(
              label: 'Zeit',
              value: '$minutes:$seconds',
              accent: scheme.secondary,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _BigStat(
              label: 'Hinweise',
              value: '$hintsUsed',
              accent: scheme.tertiary,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _BigStat(
              label: 'Punkte',
              value: '$score',
              accent: scheme.primary,
              theme: theme,
              emphasize: true,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Zur Lektion'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Erneut spielen'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.accent,
    required this.theme,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color accent;
  final ThemeData theme;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasize ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            value,
            style: (emphasize
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleLarge)
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
