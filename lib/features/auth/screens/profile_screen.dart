import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../friends/friends_providers.dart';
import 'avatar_picker_sheet.dart';

String _fmtDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).value;
    final myProfile = ref.watch(myUserProfileProvider).value;
    final avatarStyle = myProfile?.avatarStyle ?? kDefaultAvatarStyle;
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
        child: SingleChildScrollView(
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
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: false,
                              builder: (_) => AvatarPickerSheet(
                                uid: user.uid,
                                currentStyle: avatarStyle,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                UserAvatar(
                                  seed: user.uid,
                                  style: avatarStyle,
                                  fallbackText: user.displayName ?? '',
                                  size: 56,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: scheme.surface, width: 2),
                                    ),
                                    child: Icon(Icons.edit,
                                        size: 12,
                                        color: scheme.onPrimary),
                                  ),
                                ),
                              ],
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
              const SizedBox(height: 24),
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

  String _toClipboardText() {
    final buf = StringBuffer()
      ..writeln('Streak-Diagnose')
      ..writeln('=================')
      ..writeln('Spieler-ID:             ${data.playerId}')
      ..writeln('Heute (lokal):          ${_fmtDay(data.now)}')
      ..writeln('Aktueller Streak:       ${data.currentStreak} Tag(e)')
      ..writeln('Finalisierte Sessions:  ${data.finishedSessions}')
      ..writeln('Unfertige Sessions:     ${data.unfinishedSessions}')
      ..writeln('Firestore-Profil:       ${data.firestoreProfileStatus}')
      ..writeln()
      ..writeln('Distinkte Spieltage (neueste zuerst):');
    if (data.distinctDays.isEmpty) {
      buf.writeln('  — keine —');
    } else {
      for (final d in data.distinctDays) {
        buf.writeln('  • ${_fmtDay(d)}');
      }
    }
    return buf.toString();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _toClipboardText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnose in Zwischenablage kopiert.')),
    );
  }

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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Diagnose kopieren'),
          ),
        ),
        _row('Spieler-ID', shortId, mono),
        _row('Heute (lokal)', _fmtDay(data.now), mono),
        _row('Aktueller Streak', '${data.currentStreak} Tag(e)', mono),
        _row('Finalisierte Sessions', '${data.finishedSessions}', mono),
        _row('Unfertige Sessions', '${data.unfinishedSessions}', mono),
        _row('Firestore-Profil', data.firestoreProfileStatus, mono),
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
