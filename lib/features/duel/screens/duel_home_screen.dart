import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/firebase_status.dart';
import '../../../shared/providers.dart';
import '../../quiz/models/quiz_direction.dart';
import '../duel_providers.dart';
import '../models/duel.dart';
import '../services/duel_set_builder.dart';
import '../widgets/duel_incoming_dialog.dart';
import 'duel_play_screen.dart';

/// Übersicht: Eingehende Duelle, eigene offene Challenges, dann Lektionsauswahl
/// für ein neues Duell.
class DuelHomeScreen extends ConsumerWidget {
  const DuelHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lessonsAsync = ref.watch(cachedLessonsProvider);
    final direction = ref.watch(preferredDirectionProvider);
    final firebaseReady = FirebaseStatus.instance.isReady;
    final authUser =
        firebaseReady ? ref.watch(authStateProvider).value : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duell'),
      ),
      body: SafeArea(
        child: lessonsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (lessons) => CustomScrollView(
            slivers: [
              if (authUser != null) ...[
                const SliverToBoxAdapter(child: _IncomingSection()),
                const SliverToBoxAdapter(child: _OutgoingSection()),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _IntroBox(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: _DirectionRow(
                    direction: direction,
                    onToggle: () => ref
                        .read(preferredDirectionProvider.notifier)
                        .toggle(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Text(
                    'Neues Duell — Lektion auswählen',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: lessons.length,
                  itemBuilder: (context, i) {
                    final lesson = lessons[i];
                    final total = lesson.wordCount +
                        lesson.phraseCount +
                        lesson.sentenceCount;
                    final enabled = total >= kDuelMinLessonItems;
                    return _LessonTile(
                      lesson: lesson,
                      totalItems: total,
                      enabled: enabled,
                      onTap: () =>
                          _startDuel(context, ref, lesson, direction),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDuel(
    BuildContext context,
    WidgetRef ref,
    LessonsCacheData lesson,
    QuizDirection direction,
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
          lessonId: lesson.lessonId,
          direction: direction,
          rounds: rounds,
        ),
      ),
    );
  }
}

class _IncomingSection extends ConsumerWidget {
  const _IncomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(incomingPendingDuelsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (duels) {
        if (duels.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Eingehende Duelle (${duels.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final duel in duels) ...[
                _IncomingDuelTile(duel: duel),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IncomingDuelTile extends ConsumerWidget {
  const _IncomingDuelTile({required this.duel});

  final Duel duel;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => DuelIncomingDialog(duel: duel),
    );
    if (choice == null || !context.mounted) return;
    final service = ref.read(duelServiceProvider);
    if (choice == 'decline') {
      await service.declineDuel(duel.id);
      return;
    }
    // Accept
    try {
      await service.acceptDuel(duel.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte nicht annehmen: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    final direction = duel.direction == 'hr_de'
        ? QuizDirection.hrToDe
        : QuizDirection.deToHr;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuelPlayScreen(
          lessonTitle: duel.lessonTitle,
          lessonId: duel.lessonId,
          direction: direction,
          rounds: duel.rounds,
          duelId: duel.id,
          challengerTotalMs: duel.challengerResult.totalMs,
          challengerUid: duel.challengerUid,
          opponentUid: duel.opponentUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.tertiary,
                child: Text(
                  duel.challengerDisplayName.isEmpty
                      ? '?'
                      : duel.challengerDisplayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: scheme.onTertiary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${duel.challengerDisplayName} fordert dich heraus',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${duel.lessonTitle} · '
                      'Zeit zu schlagen: ${(duel.challengerResult.totalMs / 1000).toStringAsFixed(2)} s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutgoingSection extends ConsumerWidget {
  const _OutgoingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(myPendingChallengesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (duels) {
        if (duels.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Du wartest noch …',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              for (final duel in duels) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top,
                          color: scheme.onSurfaceVariant, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${duel.opponentDisplayName} · ${duel.lessonTitle}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${(duel.challengerResult.totalMs / 1000).toStringAsFixed(2)} s',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
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
