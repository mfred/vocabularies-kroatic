import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friends/friends_providers.dart';
import '../../friends/models/user_profile.dart';
import '../../quiz/models/quiz_direction.dart';
import '../../../shared/firebase_status.dart';
import '../../../shared/providers.dart';
import '../duel_providers.dart';
import '../models/duel_pair.dart';
import '../models/duel_run_result.dart';
import '../widgets/duel_friend_picker_dialog.dart';

/// Endbild nach 3 Runden Challenger-Lauf: Rundenzeiten + Gesamtzeit, plus
/// "Freund herausfordern". Bei Tap öffnet sich der FriendPicker; nach
/// Auswahl wird ein Firestore-Duel-Doc angelegt.
class DuelSummaryScreen extends ConsumerStatefulWidget {
  const DuelSummaryScreen({
    super.key,
    required this.lessonTitle,
    required this.lessonId,
    required this.direction,
    required this.rounds,
    required this.result,
  });

  final String lessonTitle;
  final String lessonId;
  final QuizDirection direction;
  final List<DuelRound> rounds;
  final DuelRunResult result;

  @override
  ConsumerState<DuelSummaryScreen> createState() => _DuelSummaryScreenState();
}

class _DuelSummaryScreenState extends ConsumerState<DuelSummaryScreen> {
  bool _sending = false;

  String _formatMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final centi = (ms % 1000) ~/ 10;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.'
          '${centi.toString().padLeft(2, '0')}';
    }
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }

  Future<void> _challengeFriend() async {
    final me = ref.read(myUserProfileProvider).value;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte zuerst anmelden, um Freunde herauszufordern.',
          ),
        ),
      );
      return;
    }
    final picked = await showDialog<UserProfile>(
      context: context,
      builder: (_) => const DuelFriendPickerDialog(),
    );
    if (picked == null || !mounted) return;

    setState(() => _sending = true);
    try {
      await ref.read(duelServiceProvider).createChallenge(
            challengerUid: me.uid,
            challengerDisplayName: me.displayName,
            opponentUid: picked.uid,
            opponentDisplayName: picked.displayName,
            lessonId: widget.lessonId,
            lessonTitle: widget.lessonTitle,
            direction: widget.direction,
            rounds: widget.rounds,
            challengerRun: widget.result,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Herausforderung an ${picked.displayName} gesendet.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firebaseReady = FirebaseStatus.instance.isReady;
    final authUser =
        firebaseReady ? ref.watch(authStateProvider).value : null;
    final canChallenge = firebaseReady && authUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duell beendet'),
            Text(
              widget.lessonTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text('🏁', style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 12),
              Text(
                'Gesamtzeit',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMs(widget.result.totalMs),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.result.totalPenaltyMs > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'inkl. ${_formatMs(widget.result.totalPenaltyMs)} Strafzeit',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.result.roundsMs.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 16,
                          color: scheme.outlineVariant,
                        ),
                      _RoundRow(
                        index: i + 1,
                        ms: widget.result.roundsMs[i],
                        penaltyMs: widget.result.penaltiesMs[i],
                        format: _formatMs,
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _sending || !canChallenge ? null : _challengeFriend,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(canChallenge
                    ? 'Freund herausfordern'
                    : 'Login erforderlich'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.replay),
                label: const Text('Andere Lektion'),
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

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.index,
    required this.ms,
    required this.penaltyMs,
    required this.format,
  });

  final int index;
  final int ms;
  final int penaltyMs;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Runde $index',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              format(ms),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (penaltyMs > 0)
              Text(
                '+${format(penaltyMs)} Strafe',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

