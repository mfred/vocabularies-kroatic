import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import '../models/session_detail.dart';
import '../widgets/attempt_row.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiel-Detail'),
      ),
      body: TabletConstrained(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Fehler: $e', textAlign: TextAlign.center),
            ),
          ),
          data: (detail) {
            if (detail == null) {
              return const Center(child: Text('Spiel nicht gefunden.'));
            }
            return _SessionContent(detail: detail);
          },
        ),
      ),
    );
  }
}

class _SessionContent extends StatelessWidget {
  const _SessionContent({required this.detail});

  final SessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = detail.totalCount == 0
        ? 0
        : ((detail.correctCount / detail.totalCount) * 100).round();
    final m = (detail.durationMs ~/ 60000).toString().padLeft(2, '0');
    final s =
        ((detail.durationMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final dateStr = _formatDate(detail.finishedAt ?? detail.startedAt);
    final dirLabel = detail.direction?.compactLabel ?? '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.lessonTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$dateStr · $dirLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(
                      label: 'Richtig',
                      value: '${detail.correctCount}/${detail.totalCount}'),
                  _Stat(label: 'Quote', value: '$percent %'),
                  _Stat(label: 'Zeit', value: '$m:$s'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Stat(label: 'Hinweise', value: '${detail.hintsUsed}'),
                  _Stat(
                    label: 'Punkte',
                    value: '${detail.scorePoints}',
                    accent: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Versuche',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (detail.attempts.isEmpty)
          Text(
            'Keine Versuche gespeichert.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final a in detail.attempts)
            AttemptRow(attempt: a, direction: detail.direction),
      ],
    );
  }

  static String _formatDate(DateTime when) {
    final d = when.day.toString().padLeft(2, '0');
    final m = when.month.toString().padLeft(2, '0');
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    return '$d.$m.${when.year} $hh:$mm';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
            ),
          ),
          Text(
            value,
            style: (accent
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleMedium)
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
