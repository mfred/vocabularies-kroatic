import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/duel_play_controller.dart';

/// Anzeige der laufenden Rundenzeit auf ~50 ms genau. Tickt nur, solange die
/// zugehörige Runde im Status [DuelPhase.playing] ist.
class DuelRoundTimerChip extends StatefulWidget {
  const DuelRoundTimerChip({super.key, required this.controller});

  final DuelPlayController controller;

  @override
  State<DuelRoundTimerChip> createState() => _DuelRoundTimerChipState();
}

class _DuelRoundTimerChipState extends State<DuelRoundTimerChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    _syncTicker();
    if (mounted) setState(() {});
  }

  void _syncTicker() {
    final shouldRun = widget.controller.phase == DuelPhase.playing;
    if (shouldRun && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) {
          if (mounted) setState(() {});
        },
      );
    } else if (!shouldRun) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _format(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final centi = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centi.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ctrl = widget.controller;
    final ms = ctrl.phase == DuelPhase.playing
        ? ctrl.currentLiveMs
        : ctrl.phase == DuelPhase.roundDone || ctrl.phase == DuelPhase.allDone
            ? ctrl.completedTotalMs
            : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            _format(ms),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
