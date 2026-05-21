import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';

String _fmtDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).value;
    final streakAsync = ref.watch(currentStreakProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mein Profil')),
        body: const Center(child: Text('Nicht angemeldet.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mein Profil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              (user.displayName?.isNotEmpty ?? false)
                                  ? user.displayName!
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? '—',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user.email ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: ListTile(
                  leading: const Text('🔥', style: TextStyle(fontSize: 22)),
                  title: const Text('Aktueller Streak'),
                  subtitle: streakAsync.when(
                    data: (n) =>
                        Text('$n Tag${n == 1 ? '' : 'e'} in Folge gespielt'),
                    loading: () => const Text('…'),
                    error: (e, _) => Text('Fehler: $e'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Streak-Diagnose'),
                  subtitle: const Text(
                    'Hilft beim Debuggen, wenn der Streak nicht hochzählt.',
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final diagAsync =
                            ref.watch(streakDiagnosticsProvider);
                        return diagAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Lade …'),
                          ),
                          error: (e, _) => Text('Fehler: $e'),
                          data: (d) => _StreakDiagnosticsView(data: d),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final auth = ref.read(authServiceProvider);
                  await auth.signOut();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Abmelden'),
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

class _StreakDiagnosticsView extends StatelessWidget {
  const _StreakDiagnosticsView({required this.data});

  final StreakDiagnostics data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: scheme.onSurfaceVariant,
    );
    final shortId = data.playerId.length > 8
        ? '${data.playerId.substring(0, 8)}…'
        : data.playerId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Spieler-ID', shortId, mono),
        _row('Heute (lokal)', _fmtDay(data.now), mono),
        _row('Aktueller Streak', '${data.currentStreak} Tag(e)', mono),
        _row('Finalisierte Sessions', '${data.finishedSessions}', mono),
        _row('Unfertige Sessions', '${data.unfinishedSessions}', mono),
        const SizedBox(height: 8),
        Text('Distinkte Spieltage (neueste zuerst):',
            style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        if (data.distinctDays.isEmpty)
          Text('— keine —', style: mono)
        else
          ...data.distinctDays.take(14).map(
                (d) => Text('  • ${_fmtDay(d)}', style: mono),
              ),
        if (data.distinctDays.length > 14)
          Text('  … (+${data.distinctDays.length - 14} älter)', style: mono),
      ],
    );
  }

  Widget _row(String label, String value, TextStyle? mono) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 170, child: Text('$label:', style: mono)),
          Expanded(child: Text(value, style: mono)),
        ],
      ),
    );
  }
}
