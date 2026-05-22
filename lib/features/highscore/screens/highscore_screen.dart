import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/firebase_status.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import '../../auth/screens/login_screen.dart';
import '../../friends/friends_providers.dart';
import '../models/leaderboard_filter.dart';
import '../models/leaderboard_range.dart';
import '../widgets/leaderboard_row.dart';
import '../widgets/score_explanation_dialog.dart';

class HighscoreScreen extends ConsumerWidget {
  const HighscoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    final firebaseReady = FirebaseStatus.instance.isReady;

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
        body: (!firebaseReady || authUser == null)
            ? _GlobalLoginCta(firebaseReady: firebaseReady)
            : TabBarView(
                children: [
                  for (final range in LeaderboardRange.values)
                    _LeaderboardTab(
                      filter: LeaderboardFilter(range: range),
                    ),
                ],
              ),
      ),
    );
  }
}

class _GlobalLoginCta extends StatelessWidget {
  const _GlobalLoginCta({required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_off,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              firebaseReady
                  ? 'Anmelden, um die globale Bestenliste zu sehen.'
                  : 'Globale Bestenliste ist nicht konfiguriert.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              firebaseReady
                  ? 'Eingeloggte Spieler messen sich weltweit.'
                  : 'Firebase muss eingerichtet sein (flutterfire configure).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (firebaseReady) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Anmelden / Registrieren'),
              ),
            ],
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
    return TabletConstrained(child: async.when(
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
        final friends = ref.watch(friendsListProvider).value ?? const [];
        final friendUids = friends.map((p) => p.uid).toSet();
        final auth = ref.watch(authStateProvider).value;
        final selfUid = auth?.uid;
        final canSendRequests = auth != null && auth.emailVerified;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderboardProvider(filter));
            await ref.read(leaderboardProvider(filter).future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final isSelf = e.uid == selfUid;
              final isFriend = friendUids.contains(e.uid);
              final showAddButton =
                  canSendRequests && !isSelf && !isFriend;
              return LeaderboardRow(
                entry: e,
                isSelf: isSelf,
                isFriend: isFriend,
                onSendRequest: !showAddButton
                    ? null
                    : () async {
                        final authNow =
                            ref.read(authStateProvider).value;
                        if (authNow == null) {
                          throw StateError('Nicht eingeloggt.');
                        }
                        var me = ref.read(myUserProfileProvider).value;
                        me ??= await ref
                            .read(userProfileServiceProvider)
                            .ensureProfile(authNow);
                        await ref.read(friendServiceProvider).sendRequest(
                              fromUid: me.uid,
                              fromDisplayName: me.displayName,
                              toUid: e.uid,
                            );
                      },
              );
            },
          ),
        );
      },
    ));
  }
}
