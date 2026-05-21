import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers.dart';
import '../../quiz/models/quiz_direction.dart';
import '../duel_providers.dart';
import '../services/duel_set_builder.dart';
import 'duel_play_screen.dart';

/// Übersicht: Richtung wählen, Lektion antippen → Duell-Probe-Spiel starten.
class DuelHomeScreen extends ConsumerWidget {
  const DuelHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lessonsAsync = ref.watch(cachedLessonsProvider);
    final direction = ref.watch(preferredDirectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duell'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroBox(),
              const SizedBox(height: 16),
              _DirectionRow(
                direction: direction,
                onToggle: () =>
                    ref.read(preferredDirectionProvider.notifier).toggle(),
              ),
              const SizedBox(height: 12),
              Text(
                'Lektion auswählen',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: lessonsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'Fehler: $e',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  data: (lessons) => _LessonList(
                    lessons: lessons,
                    direction: direction,
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

class _IntroBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, color: scheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '3 Runden, 5 Vokabelpaare pro Runde. '
              'Schnelles Ziehen — falsche Zuordnung kostet 0,2 s.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionRow extends StatelessWidget {
  const _DirectionRow({required this.direction, required this.onToggle});

  final QuizDirection direction;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeHr = direction == QuizDirection.deToHr;
    final from = isDeHr ? '🇩🇪 Deutsch' : '🇭🇷 Kroatisch';
    final to = isDeHr ? '🇭🇷 Kroatisch' : '🇩🇪 Deutsch';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$from  →  $to',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Richtung wechseln',
            onPressed: onToggle,
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
    );
  }
}

class _LessonList extends ConsumerWidget {
  const _LessonList({required this.lessons, required this.direction});

  final List<LessonsCacheData> lessons;
  final QuizDirection direction;

  Future<void> _startDuel(
    BuildContext context,
    WidgetRef ref,
    LessonsCacheData lesson,
  ) async {
    final builder = ref.read(duelSetBuilderProvider);
    final rounds = await builder.build(
      lessonId: lesson.lessonId,
      direction: direction,
    );
    if (!context.mounted) return;
    if (rounds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lektion hat zu wenige Vokabeln für ein Duell '
            '(mindestens $kDuelMinLessonItems benötigt).',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuelPlayScreen(
          lessonTitle: lesson.titleDe,
          rounds: rounds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (lessons.isEmpty) {
      return Center(
        child: Text(
          'Noch keine Lektionen geladen.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final lesson = lessons[index];
        final total =
            lesson.wordCount + lesson.phraseCount + lesson.sentenceCount;
        final enabled = total >= kDuelMinLessonItems;
        return _LessonTile(
          lesson: lesson,
          totalItems: total,
          enabled: enabled,
          onTap: () => _startDuel(context, ref, lesson),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: lessons.length,
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.totalItems,
    required this.enabled,
    required this.onTap,
  });

  final LessonsCacheData lesson;
  final int totalItems;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: enabled ? scheme.surface : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt,
                color: enabled ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.titleDe,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? '$totalItems Vokabeln'
                          : '$totalItems Vokabeln — zu wenige für ein Duell',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
