import 'package:flutter/material.dart';

import '../controllers/duel_play_controller.dart';
import '../models/duel_pair.dart';
import '../widgets/countdown_overlay.dart';
import '../widgets/duel_round_board.dart';
import '../widgets/duel_round_timer_chip.dart';
import 'duel_summary_screen.dart';

/// Orchestriert die drei Runden mit Countdown vor jeder Runde und der
/// Übergangs-Anzeige zwischen Runden. Nach der letzten Runde push auf den
/// Summary-Screen.
class DuelPlayScreen extends StatefulWidget {
  const DuelPlayScreen({
    super.key,
    required this.lessonTitle,
    required this.rounds,
  });

  final String lessonTitle;
  final List<DuelRound> rounds;

  @override
  State<DuelPlayScreen> createState() => _DuelPlayScreenState();
}

class _DuelPlayScreenState extends State<DuelPlayScreen> {
  late final DuelPlayController _controller;

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
    if (_controller.phase == DuelPhase.allDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DuelSummaryScreen(
              lessonTitle: widget.lessonTitle,
              result: _controller.buildResult(),
            ),
          ),
        );
      });
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            'Runde ${controller.roundIndex + 1} geschafft!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatMs(justFinished),
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
    );
  }
}
