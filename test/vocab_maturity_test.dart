import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/services/sm2_scheduler.dart';
import 'package:vocabularies_kroatic/features/quiz/services/vocab_maturity.dart';

/// Konstruiert einen SM-2-Zustand mit den für die Reife-Einstufung relevanten
/// Feldern (Intervall + Wiederholungen); der Rest ist hier belanglos.
Sm2State state({required int reps, required int interval}) => Sm2State(
      easeFactor: 2.5,
      repetitions: reps,
      intervalDays: interval,
      dueAtMs: 0,
      lastReviewedMs: 0,
    );

void main() {
  group('maturityBucketOf', () {
    test('Intervall < 6 → am Lernen (frisch / 1× gewusst / nach Fehler)', () {
      expect(maturityBucketOf(state(reps: 0, interval: 0)),
          VocabMaturityBucket.learning);
      // Fehlschlag setzt reps=0, interval=1 (siehe Sm2Scheduler).
      expect(maturityBucketOf(state(reps: 0, interval: 1)),
          VocabMaturityBucket.learning);
      // Erst einmal richtig → interval 1, noch am Lernen.
      expect(maturityBucketOf(state(reps: 1, interval: 1)),
          VocabMaturityBucket.learning);
    });

    test('Intervall 6..20 → jung', () {
      expect(maturityBucketOf(state(reps: 2, interval: 6)),
          VocabMaturityBucket.young);
      expect(maturityBucketOf(state(reps: 3, interval: 16)),
          VocabMaturityBucket.young);
      expect(maturityBucketOf(state(reps: 3, interval: 20)),
          VocabMaturityBucket.young);
    });

    test('Intervall ≥ 21 → reif', () {
      expect(maturityBucketOf(state(reps: 3, interval: 21)),
          VocabMaturityBucket.mature);
      expect(maturityBucketOf(state(reps: 5, interval: 60)),
          VocabMaturityBucket.mature);
    });
  });

  group('buildVocabMaturity', () {
    test('leer → isEmpty, total 0', () {
      final m = buildVocabMaturity(const []);
      expect(m.isEmpty, isTrue);
      expect(m.total, 0);
      expect(m.learning, 0);
      expect(m.young, 0);
      expect(m.mature, 0);
    });

    test('zählt jede Stufe korrekt und summiert total', () {
      final m = buildVocabMaturity([
        state(reps: 0, interval: 1), // am Lernen
        state(reps: 1, interval: 1), // am Lernen
        state(reps: 2, interval: 6), // jung
        state(reps: 3, interval: 16), // jung
        state(reps: 4, interval: 40), // reif
      ]);
      expect(m.learning, 2);
      expect(m.young, 2);
      expect(m.mature, 1);
      expect(m.total, 5);
      expect(m.isEmpty, isFalse);
    });

    test('Grenzfall Intervall genau 21 zählt als reif (nicht jung)', () {
      final m = buildVocabMaturity([state(reps: 3, interval: 21)]);
      expect(m.mature, 1);
      expect(m.young, 0);
    });
  });
}
