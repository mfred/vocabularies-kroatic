import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../shared/providers.dart';
import '../duel/duel_launcher.dart';
import '../duel/duel_providers.dart';
import '../duel/services/duel_set_builder.dart';
import '../duel/widgets/incoming_duel_tile.dart';
import '../quiz/screens/quiz_setup_screen.dart';
import 'vocabulary_list_screen.dart';

class LessonMenuScreen extends ConsumerWidget {
  const LessonMenuScreen({super.key, required this.lesson});

  final LessonsCacheData lesson;

  int get _totalItems =>
      lesson.wordCount + lesson.phraseCount + lesson.sentenceCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wrongCountAsync =
        ref.watch(wrongItemsCountProvider(lesson.lessonId));
    final wrongCount = wrongCountAsync.maybeWhen(
      data: (n) => n,
      orElse: () => null,
    );
    final reviewSubtitle = switch (wrongCount) {
      null => 'Lade …',
      0 => 'Keine offenen Fehler — alles richtig gewusst.',
      1 => '1 Vokabel, die du zuletzt falsch hattest.',
      _ => '$wrongCount Vokabeln, die du zuletzt falsch hattest.',
    };

    final duelEnabled = _totalItems >= kDuelMinLessonItems;
    final duelSubtitle = duelEnabled
        ? '3 Runden auf Zeit — schnelles Paaren gegen Freunde.'
        : 'Mindestens $kDuelMinLessonItems Vokabeln nötig (aktuell $_totalItems).';
    final direction = ref.watch(preferredDirectionProvider);

    final incomingForLesson = ref.watch(incomingPendingDuelsProvider).maybeWhen(
          data: (duels) =>
              duels.where((d) => d.lessonId == lesson.lessonId).toList(),
          orElse: () => const [],
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.titleDe),
            Text(
              lesson.titleHr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (incomingForLesson.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('⚔️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Eingehende Herausforderungen (${incomingForLesson.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final duel in incomingForLesson) ...[
                  IncomingDuelTile(duel: duel),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
              ],
              Text(
                'Was möchtest du tun?',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.play_circle_outline,
                title: 'Quiz starten',
                subtitle:
                    'Spielmodus und Richtung wählen — dann 10 Fragen.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizSetupScreen(lesson: lesson),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.menu_book_outlined,
                title: 'Vokabeln lernen',
                subtitle:
                    '$_totalItems Einträge mit Übersetzung, Lautschrift und Anhören.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VocabularyListScreen(lesson: lesson),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.refresh,
                title: 'Fehler ausbessern',
                subtitle: reviewSubtitle,
                enabled: (wrongCount ?? 0) > 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuizSetupScreen(
                        lesson: lesson,
                        reviewMode: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.bolt,
                title: 'Duell',
                subtitle: duelSubtitle,
                enabled: duelEnabled,
                onTap: () =>
                    startDuelForLesson(context, ref, lesson, direction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = enabled ? scheme.primary : scheme.outline;
    final titleColor =
        enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.7);
    final subtitleColor = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.6);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          width: 1.5,
          color: scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
