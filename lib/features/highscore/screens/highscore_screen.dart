import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../models/leaderboard_filter.dart';
import '../models/leaderboard_range.dart';
import '../widgets/leaderboard_row.dart';
import '../widgets/lesson_filter_bar.dart';
import '../widgets/score_explanation_dialog.dart';
import 'session_detail_screen.dart';

class HighscoreScreen extends ConsumerStatefulWidget {
  const HighscoreScreen({super.key});

  @override
  ConsumerState<HighscoreScreen> createState() => _HighscoreScreenState();
}

class _HighscoreScreenState extends ConsumerState<HighscoreScreen> {
  String? _selectedLessonId;

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(cachedLessonsProvider);
    return DefaultTabController(
      length: LeaderboardRange.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bestenliste'),
          actions: [
            IconButton(
              tooltip: 'Punkte erklärt',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showScoreExplanationDialog(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              for (final range in LeaderboardRange.values)
                Tab(text: range.label),
            ],
          ),
        ),
        body: Column(
          children: [
            lessonsAsync.maybeWhen(
              data: (lessons) => LessonFilterBar(
                lessons: lessons,
                selectedLessonId: _selectedLessonId,
                onSelected: (id) =>
                    setState(() => _selectedLessonId = id),
              ),
              orElse: () => const SizedBox(height: 48),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final range in LeaderboardRange.values)
                    _LeaderboardTab(
                      filter: LeaderboardFilter(
                        range: range,
                        lessonId: _selectedLessonId,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.filter});

  final LeaderboardFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(filter));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Fehler: $e', textAlign: TextAlign.center),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(leaderboardProvider(filter));
              await ref.read(leaderboardProvider(filter).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Noch keine Spiele in diesem Zeitraum.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Starte ein Quiz aus einer Lektion.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderboardProvider(filter));
            await ref.read(leaderboardProvider(filter).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return LeaderboardRow(
                entry: entry,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionDetailScreen(
                        sessionId: entry.sessionId,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
