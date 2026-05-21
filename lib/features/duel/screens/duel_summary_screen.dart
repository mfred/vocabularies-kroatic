import 'package:flutter/material.dart';

import '../models/duel_run_result.dart';

/// Endbild nach 3 Runden: Rundenzeiten + Gesamtzeit, plus Platzhalter für die
/// Herausforderungs-Funktion (kommt in Iteration 1.0.24).
class DuelSummaryScreen extends StatelessWidget {
  const DuelSummaryScreen({
    super.key,
    required this.lessonTitle,
    required this.result,
  });

  final String lessonTitle;
  final DuelRunResult result;

  String _formatMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final centi = (ms % 1000) ~/ 10;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.'
          '${centi.toString().padLeft(2, '0')}';
    }
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duell beendet'),
            Text(
              lessonTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text('🏁', style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 12),
              Text(
                'Gesamtzeit',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMs(result.totalMs),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result.totalPenaltyMs > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'inkl. ${_formatMs(result.totalPenaltyMs)} Strafzeit',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < result.roundsMs.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 16,
                          color: scheme.outlineVariant,
                        ),
                      _RoundRow(
                        index: i + 1,
                        ms: result.roundsMs[i],
                        penaltyMs: result.penaltiesMs[i],
                        format: _formatMs,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Herausforderungen an Freunde kommen in der nächsten Iteration.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send),
                label: const Text('Freund herausfordern'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.replay),
                label: const Text('Andere Lektion'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.index,
    required this.ms,
    required this.penaltyMs,
    required this.format,
  });

  final int index;
  final int ms;
  final int penaltyMs;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Runde $index',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              format(ms),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (penaltyMs > 0)
              Text(
                '+${format(penaltyMs)} Strafe',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
