import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../quiz/models/quiz_direction.dart';
import '../controllers/duel_play_controller.dart';
import '../duel_providers.dart';
import '../models/duel_pair.dart';
import '../widgets/countdown_overlay.dart';
import '../widgets/duel_round_board.dart';
import '../widgets/duel_round_timer_chip.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import 'duel_result_compare_screen.dart';
import 'duel_summary_screen.dart';

/// Orchestriert die drei Runden. Zwei Modi:
/// - Free play (Challenger): `duelId == null` → nach Ende → DuelSummaryScreen
///   mit Option zum Herausfordern.
/// - Opponent: `duelId != null` → nach Ende → submitOpponentResult +
///   DuelResultCompareScreen.
class DuelPlayScreen extends ConsumerStatefulWidget {
  const DuelPlayScreen({
    super.key,
    required this.lessonTitle,
    required this.lessonId,
    required this.direction,
    required this.rounds,
    this.duelId,
    this.challengerTotalMs,
    this.challengerUid,
    this.opponentUid,
  });

  final String lessonTitle;
  final String lessonId;
  final QuizDirection direction;
  final List<DuelRound> rounds;

  /// Wenn gesetzt: Opponent-Modus, Ergebnis wird an Firestore submitted.
  final String? duelId;
  final int? challengerTotalMs;
  final String? challengerUid;
  final String? opponentUid;

  bool get isOpponentMode => duelId != null;

  @override
  ConsumerState<DuelPlayScreen> createState() => _DuelPlayScreenState();
}

class _DuelPlayScreenState extends ConsumerState<DuelPlayScreen> {
  late final DuelPlayController _controller;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = DuelPlayController(rounds: widget.rounds);
    _controller.addListener(_onControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.beginCountdown();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
    if (_controller.phase == DuelPhase.allDone && !_submitted) {
      _submitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onAllDone());
    }
  }

  Future<void> _onAllDone() async {
    if (!mounted) return;
    final result = _controller.buildResult();

    // Duell als finalisierte Session in `quizSessions` ablegen (mit
    // mode='duel_local'), damit der Streak hochzählt. Best-effort —
    // Fehler hier dürfen den Navigations-Flow nicht blockieren.
    await _recordDuelInStreak(result);

    if (widget.isOpponentMode) {
      // In Firestore submitten und zum Vergleichs-Screen wechseln.
      final duelId = widget.duelId!;
      try {
        await ref.read(duelServiceProvider).submitOpponentResult(
              duelId: duelId,
              opponentRun: result,
              challengerTotalMs: widget.challengerTotalMs ?? 0,
              challengerUid: widget.challengerUid ?? '',
              opponentUid: widget.opponentUid ?? '',
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konnte Ergebnis nicht senden: $e')),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DuelResultCompareScreen(duelId: duelId),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DuelSummaryScreen(
          lessonTitle: widget.lessonTitle,
          lessonId: widget.lessonId,
          direction: widget.direction,
          rounds: widget.rounds,
          result: result,
        ),
      ),
    );
  }

  Future<void> _recordDuelInStreak(dynamic result) async {
    try {
      final db = ref.read(databaseProvider);
      final player = await ref.read(currentPlayerProvider.future);
      final totalPairs = widget.rounds.fold<int>(
        0,
        (sum, r) => sum + r.pairs.length,
      );
      final sessionId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final totalMs = result.totalMs as int;
      final startedAt = now - totalMs;
      await db.insertQuizSession(
        QuizSessionsCompanion.insert(
          id: sessionId,
          playerId: player.id,
          lessonId: widget.lessonId,
          mode: const Value('duel_local'),
          direction: Value(widget.direction.code),
          startedAt: startedAt,
          totalCount: Value(totalPairs),
        ),
      );
      await db.finalizeQuizSession(
        sessionId: sessionId,
        finishedAt: now,
        durationMs: totalMs,
        correctCount: totalPairs,
        totalCount: totalPairs,
        hintsUsed: 0,
        scorePoints: 0,
      );
      // Streak-Provider invalidieren, damit das nächste Profil-Öffnen den
      // neuen Wert lädt.
      ref.invalidate(currentStreakProvider);
      ref.invalidate(streakDiagnosticsProvider);
    } catch (_) {
      // Best effort — kein Stopper für den Navigationsfluss.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = _controller.phase;
    final roundLabel =
        'Runde ${_controller.roundIndex + 1} / ${widget.rounds.length}';

    return PopScope(
      canPop: phase == DuelPhase.allDone,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmExit(context);
        if (shouldPop && context.mounted) {
          if (!mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(roundLabel),
              Text(
                widget.lessonTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: DuelRoundTimerChip(controller: _controller),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: TabletConstrained(
            maxWidth: kTabletMaxBoardWidth,
            child: Stack(
            children: [
              Column(
                children: [
                  _PenaltyLine(controller: _controller),
                  Expanded(
                    child: phase == DuelPhase.roundDone
                        ? _RoundDoneView(
                            controller: _controller,
                            onContinue: _controller.advanceToNextRound,
                          )
                        : DuelRoundBoard(controller: _controller),
                  ),
                ],
              ),
              if (phase == DuelPhase.countdown)
                Positioned.fill(
                  child: CountdownOverlay(
                    onFinished: _controller.onCountdownFinished,
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    if (_controller.phase == DuelPhase.allDone) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duell abbrechen?'),
        content: const Text(
          'Dein bisheriger Lauf geht verloren. Trotzdem zurück?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Weiter spielen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _PenaltyLine extends StatelessWidget {
  const _PenaltyLine({required this.controller});

  final DuelPlayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final penalty = controller.currentPenaltyMs;
    if (controller.phase != DuelPhase.playing || penalty == 0) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: scheme.error),
          const SizedBox(width: 6),
          Text(
            'Strafzeit: +${(penalty / 1000).toStringAsFixed(1)} s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundDoneView extends StatelessWidget {
  const _RoundDoneView({
    required this.controller,
    required this.onContinue,
  });

  final DuelPlayController controller;
  final VoidCallback onContinue;

  String _formatMs(int ms) {
    final s = (ms / 1000).toStringAsFixed(2);
    return '$s s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = controller.buildResult();
    final justFinished = result.roundsMs.last;
    return TabletConstrained(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'Runde ${controller.roundIndex + 1} geschafft!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatMs(justFinished),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (result.penaltiesMs.last > 0) ...[
              const SizedBox(height: 4),
              Text(
                'davon ${_formatMs(result.penaltiesMs.last)} Strafzeit',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Weiter zur nächsten Runde'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
