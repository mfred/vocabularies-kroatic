import 'dart:math';

/// SM-2-Spaced-Repetition-Zustand eines Items (siehe PROJECT.md §7).
///
/// Der Zustand wird nicht persistiert, sondern bei Bedarf aus der
/// `quiz_attempts`-Historie gefaltet (siehe `AppDatabase.sm2StatesByItem`).
/// Die SM-2-Rekurrenz ist deterministisch über die Antwortfolge, daher ist
/// das Falten mathematisch äquivalent zu gespeichertem Zustand.
class Sm2State {
  const Sm2State({
    required this.easeFactor,
    required this.repetitions,
    required this.intervalDays,
    required this.dueAtMs,
    required this.lastReviewedMs,
  });

  /// Startwert vor dem ersten Versuch.
  factory Sm2State.initial() => const Sm2State(
        easeFactor: 2.5,
        repetitions: 0,
        intervalDays: 0,
        dueAtMs: 0,
        lastReviewedMs: 0,
      );

  final double easeFactor;
  final int repetitions;
  final int intervalDays;
  final int dueAtMs;
  final int lastReviewedMs;
}

class Sm2Scheduler {
  const Sm2Scheduler();

  static const int _msPerDay = 86400000;
  static const double _minEase = 1.3;

  /// quality < 3 gilt als Fehlschlag und setzt die Wiederholungskette zurück.
  static const int _passThreshold = 3;

  /// Wendet eine Bewertung (0–5) auf den bisherigen Zustand an und liefert den
  /// neuen Zustand inkl. neuem Fälligkeitszeitpunkt.
  Sm2State applyQuality(
    Sm2State prev, {
    required int quality,
    required int reviewedAtMs,
  }) {
    if (quality < _passThreshold) {
      return Sm2State(
        easeFactor: max(_minEase, prev.easeFactor - 0.2),
        repetitions: 0,
        intervalDays: 1,
        dueAtMs: reviewedAtMs + _msPerDay,
        lastReviewedMs: reviewedAtMs,
      );
    }

    final newReps = prev.repetitions + 1;
    final int newInterval;
    if (newReps == 1) {
      newInterval = 1;
    } else if (newReps == 2) {
      newInterval = 6;
    } else {
      newInterval = (prev.intervalDays * prev.easeFactor).round();
    }

    final newEase = max(
      _minEase,
      prev.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)),
    );

    return Sm2State(
      easeFactor: newEase,
      repetitions: newReps,
      intervalDays: newInterval,
      dueAtMs: reviewedAtMs + newInterval * _msPerDay,
      lastReviewedMs: reviewedAtMs,
    );
  }
}

/// SM-2-Bewertung aus den in `quiz_attempts` vorhandenen Signalen. Bewusst
/// schlicht gehalten und über benannte Konstanten leicht justierbar; eine
/// `responseMs`-Feinabstufung zwischen 4 und 5 wird vorerst weggelassen.
const int kQualityWrong = 2;
const int kQualityCorrectWithHint = 3;
const int kQualityCorrect = 5;

int qualityFromAttempt({required bool wasCorrect, required bool hintUsed}) {
  if (!wasCorrect) return kQualityWrong;
  return hintUsed ? kQualityCorrectWithHint : kQualityCorrect;
}
