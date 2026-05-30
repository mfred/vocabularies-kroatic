import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../streaks/services/activity_heatmap.dart';
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
        child: TabletConstrained(
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
                child: const _ActivityHeatmapTile(),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: const _PlayerStatsTile(),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: const _VocabMaturityTile(),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: _ReminderToggleTile(),
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

/// „Wortschatz-Reife": segmentierter Balken über die SM-2-Reife-Stufen der
/// geübten Karten (Am Lernen / Jung / Reif). Reife-Metapher in den Farben:
/// orange (unreif) → hellgrün (jung) → grün (reif).
class _VocabMaturityTile extends ConsumerWidget {
  const _VocabMaturityTile();

  static const _learningColor = Color(0xFFE8A33D); // orange — am Lernen
  static const _youngColor = Color(0xFF8BC34A); // hellgrün — jung
  static const _matureColor = Color(0xFF43A047); // grün — reif

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(vocabMaturityProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌱', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                'Wortschatz-Reife',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Lade …'),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (m) {
              if (m.isEmpty) {
                return Text(
                  'Noch keine geübten Vokabeln — sobald du Quizze spielst, '
                  'reifen deine Karten hier von „am Lernen" zu „reif".',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MaturityBar(
                    learning: m.learning,
                    young: m.young,
                    mature: m.mature,
                    learningColor: _learningColor,
                    youngColor: _youngColor,
                    matureColor: _matureColor,
                  ),
                  const SizedBox(height: 14),
                  _MaturityLegendRow(
                    color: _matureColor,
                    label: 'Reif',
                    hint: 'sicher gewusst (≥ 21 Tage Intervall)',
                    count: m.mature,
                  ),
                  _MaturityLegendRow(
                    color: _youngColor,
                    label: 'Jung',
                    hint: 'auf gutem Weg',
                    count: m.young,
                  ),
                  _MaturityLegendRow(
                    color: _learningColor,
                    label: 'Am Lernen',
                    hint: 'noch wackelig',
                    count: m.learning,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${m.total} Lernkarten — je Vokabel und Richtung gezählt.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Gestapelter Anteilsbalken: reif → jung → am Lernen (von „fertig" zu „offen").
/// Leere Segmente werden weggelassen, die äußeren Ecken sind gerundet.
class _MaturityBar extends StatelessWidget {
  const _MaturityBar({
    required this.learning,
    required this.young,
    required this.mature,
    required this.learningColor,
    required this.youngColor,
    required this.matureColor,
  });

  final int learning;
  final int young;
  final int mature;
  final Color learningColor;
  final Color youngColor;
  final Color matureColor;

  @override
  Widget build(BuildContext context) {
    final segs = <({int count, Color color})>[
      (count: mature, color: matureColor),
      (count: young, color: youngColor),
      (count: learning, color: learningColor),
    ].where((s) => s.count > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (final s in segs)
              Expanded(flex: s.count, child: ColoredBox(color: s.color)),
          ],
        ),
      ),
    );
  }
}

/// Legenden-Zeile: Farbtupfer + Label + Kurz-Erklärung + Zähler.
class _MaturityLegendRow extends StatelessWidget {
  const _MaturityLegendRow({
    required this.color,
    required this.label,
    required this.hint,
    required this.count,
  });

  final Color color;
  final String label;
  final String hint;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style:
                theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            '$count',
            style:
                theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PlayerStatsTile extends ConsumerWidget {
  const _PlayerStatsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(playerStatsProvider);
    final longestAsync = ref.watch(longestStreakProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                'Deine Stats',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Lade …'),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (s) {
              final longest = longestAsync.value;
              return Column(
                children: [
                  _StatsRow(
                    label: 'Quizze gesamt',
                    value: '${s.totalSessions}',
                  ),
                  _StatsRow(
                    label: 'Diese Woche',
                    value: '${s.sessionsThisWeek}',
                  ),
                  _StatsRow(
                    label: 'Trefferquote',
                    value: s.hasAnySession
                        ? '${s.correctRatioPercent} %'
                        : '—',
                  ),
                  _StatsRow(
                    label: 'Längster Streak',
                    value: longest == null
                        ? '…'
                        : '$longest Tag${longest == 1 ? '' : 'e'}',
                  ),
                  _StatsRow(
                    label: 'Lieblings-Lektion',
                    value: s.favouriteLessonTitle == null
                        ? '—'
                        : '${s.favouriteLessonTitle} (${s.favouriteLessonSessions})',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityHeatmapTile extends ConsumerWidget {
  const _ActivityHeatmapTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final heatmapAsync = ref.watch(activityHeatmapProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗓️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                'Aktivität',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          heatmapAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Lade …'),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (h) {
              if (h.isEmpty) {
                return Text(
                  'Noch keine abgeschlossenen Quizze — leg los, dann füllt '
                  'sich dein Kalender.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeatmapGrid(heatmap: h),
                  const SizedBox(height: 10),
                  Text(
                    'An ${h.activeDays} Tag${h.activeDays == 1 ? '' : 'en'} '
                    'gespielt — ${h.totalSessions} '
                    'Quiz${h.totalSessions == 1 ? '' : 'ze'} in 13 Wochen.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Rendert das Wochen-×-Wochentag-Raster der [ActivityHeatmap] als Quadrat-Grid.
class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.heatmap});

  final ActivityHeatmap heatmap;

  static const _cell = 14.0;
  static const _gap = 3.0;

  /// Farbe einer Zelle: leere Tage in gedämpftem Surface-Ton, aktive Tage in
  /// vier Intensitätsstufen der Primärfarbe relativ zu [ActivityHeatmap.maxCount].
  Color _colorFor(int? count, ColorScheme scheme) {
    if (count == null) return Colors.transparent;
    if (count == 0) return scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final max = heatmap.maxCount;
    // 1..4 Stufen.
    final level = max <= 1
        ? 4
        : (1 + (3 * (count - 1) / (max - 1)).round()).clamp(1, 4);
    final alpha = [0.30, 0.50, 0.72, 1.0][level - 1];
    return scheme.primary.withValues(alpha: alpha);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grid = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < heatmap.weeks; w++)
          Padding(
            padding: EdgeInsets.only(right: w == heatmap.weeks - 1 ? 0 : _gap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var d = 0; d < 7; d++)
                  Padding(
                    padding: EdgeInsets.only(bottom: d == 6 ? 0 : _gap),
                    child: Container(
                      width: _cell,
                      height: _cell,
                      decoration: BoxDecoration(
                        color: _colorFor(heatmap.cells[w][d], scheme),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: grid,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('weniger',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
            const SizedBox(width: 6),
            for (final a in const [0.0, 0.30, 0.50, 0.72, 1.0])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: a == 0.0
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
                        : scheme.primary.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 3),
            Text('mehr',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(reminderEnabledProvider);
    final enabled = enabledAsync.maybeWhen(data: (v) => v, orElse: () => true);
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Streak-Erinnerung am Abend'),
      subtitle: const Text(
        '20 Uhr, nur bei Streak ab 3 Tagen und wenn heute nicht gespielt.',
      ),
      value: enabled,
      onChanged: (v) async {
        final player = await ref.read(currentPlayerProvider.future);
        await ref.read(databaseProvider).setReminderEnabled(player.id, v);
        ref.invalidate(reminderEnabledProvider);
        if (v) {
          await ref.read(reminderServiceProvider).requestPermissionIfNeeded();
          await ref.read(reminderServiceProvider).rescheduleReminder(player.id);
        } else {
          await ref.read(reminderServiceProvider).cancel();
        }
      },
    );
  }
}
