import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../models/leaderboard_range.dart';
import '../widgets/leaderboard_row.dart';
import '../widgets/score_explanation_dialog.dart';

class HighscoreScreen extends StatelessWidget {
  const HighscoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        body: TabBarView(
          children: [
            for (final range in LeaderboardRange.values)
              _LeaderboardTab(range: range),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.range});

  final LeaderboardRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(range));
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 56,
                    color:
                        Theme.of(context).colorScheme.outline,
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
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderboardProvider(range));
            await ref.read(leaderboardProvider(range).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: entries.length,
            itemBuilder: (context, i) =>
                LeaderboardRow(entry: entries[i]),
          ),
        );
      },
    );
  }
}
