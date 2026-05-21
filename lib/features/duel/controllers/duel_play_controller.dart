import 'package:flutter/foundation.dart';

import '../models/duel_pair.dart';
import '../models/duel_run_result.dart';

enum DuelPhase { idle, countdown, playing, roundDone, allDone }

const int kDuelPenaltyMs = 200;

/// Lokaler Spielzustand für einen Duell-Lauf. Hält Stopwatch + Strafzeit pro
/// laufender Runde und kumuliert Ergebnisse über alle Runden.
class DuelPlayController extends ChangeNotifier {
  DuelPlayController({required this.rounds}) : assert(rounds.isNotEmpty);

  final List<DuelRound> rounds;

  final Stopwatch _stopwatch = Stopwatch();
  DuelPhase _phase = DuelPhase.idle;
  int _roundIndex = 0;
  int _penaltyMs = 0;
  final Set<String> _matchedThisRound = <String>{};
  final List<int> _roundsMs = [];
  final List<int> _penaltiesMs = [];

  DuelPhase get phase => _phase;
  int get roundIndex => _roundIndex;
  DuelRound get currentRound => rounds[_roundIndex];
  Set<String> get matchedItemIds => _matchedThisRound;
  int get currentPenaltyMs => _penaltyMs;

  /// Live-Lesen der laufenden Rundenzeit (Stopwatch + bisherige Strafen).
  int get currentLiveMs =>
      _stopwatch.elapsedMilliseconds + _penaltyMs;

  /// Aufsummierte Zeit aller bereits abgeschlossenen Runden.
  int get completedTotalMs => _roundsMs.fold(0, (a, b) => a + b);

  bool get isLastRound => _roundIndex == rounds.length - 1;

  /// Startet die Countdown-Phase für die aktuelle Runde.
  void beginCountdown() {
    _matchedThisRound.clear();
    _penaltyMs = 0;
    _stopwatch.reset();
    _phase = DuelPhase.countdown;
    notifyListeners();
  }

  /// Wird vom CountdownOverlay aufgerufen, sobald "GO" geflasht hat.
  void onCountdownFinished() {
    _stopwatch.start();
    _phase = DuelPhase.playing;
    notifyListeners();
  }

  /// Eine korrekte Zuordnung wurde abgelegt.
  void registerCorrectMatch(String itemId) {
    if (_phase != DuelPhase.playing) return;
    if (!_matchedThisRound.add(itemId)) return;
    if (_matchedThisRound.length >= currentRound.pairs.length) {
      _stopwatch.stop();
      _roundsMs.add(_stopwatch.elapsedMilliseconds + _penaltyMs);
      _penaltiesMs.add(_penaltyMs);
      _phase = isLastRound ? DuelPhase.allDone : DuelPhase.roundDone;
    }
    notifyListeners();
  }

  /// Ein Drag wurde verworfen / falsch abgelegt → +200 ms.
  void registerIncorrectAttempt() {
    if (_phase != DuelPhase.playing) return;
    _penaltyMs += kDuelPenaltyMs;
    notifyListeners();
  }

  /// Nächste Runde vorbereiten (nur erlaubt nach roundDone).
  void advanceToNextRound() {
    if (_phase != DuelPhase.roundDone) return;
    _roundIndex += 1;
    beginCountdown();
  }

  DuelRunResult buildResult() {
    return DuelRunResult(
      roundsMs: List<int>.from(_roundsMs),
      penaltiesMs: List<int>.from(_penaltiesMs),
    );
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }
}
