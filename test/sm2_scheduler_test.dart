import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/services/sm2_scheduler.dart';

const int _day = 86400000;

void main() {
  const scheduler = Sm2Scheduler();

  group('Sm2Scheduler.applyQuality', () {
    test('drei perfekte Antworten: Intervalle 1 → 6 → 16, Ease steigt', () {
      var s = Sm2State.initial();

      s = scheduler.applyQuality(s, quality: 5, reviewedAtMs: 0);
      expect(s.repetitions, 1);
      expect(s.intervalDays, 1);
      expect(s.easeFactor, closeTo(2.6, 1e-9));
      expect(s.dueAtMs, 1 * _day);

      s = scheduler.applyQuality(s, quality: 5, reviewedAtMs: _day);
      expect(s.repetitions, 2);
      expect(s.intervalDays, 6);
      expect(s.easeFactor, closeTo(2.7, 1e-9));
      expect(s.dueAtMs, _day + 6 * _day);

      s = scheduler.applyQuality(s, quality: 5, reviewedAtMs: 10 * _day);
      expect(s.repetitions, 3);
      // round(prevInterval 6 * prevEase 2.7) = round(16.2) = 16.
      expect(s.intervalDays, 16);
      expect(s.easeFactor, closeTo(2.8, 1e-9));
      expect(s.dueAtMs, 10 * _day + 16 * _day);
    });

    test('Fehlschlag setzt Kette zurück und senkt Ease um 0.2', () {
      var s = scheduler.applyQuality(Sm2State.initial(),
          quality: 5, reviewedAtMs: 0);
      expect(s.easeFactor, closeTo(2.6, 1e-9));

      s = scheduler.applyQuality(s, quality: 2, reviewedAtMs: 5 * _day);
      expect(s.repetitions, 0);
      expect(s.intervalDays, 1);
      expect(s.easeFactor, closeTo(2.4, 1e-9));
      expect(s.dueAtMs, 5 * _day + 1 * _day);
    });

    test('Ease fällt nie unter 1.3', () {
      const low = Sm2State(
        easeFactor: 1.3,
        repetitions: 0,
        intervalDays: 1,
        dueAtMs: 0,
        lastReviewedMs: 0,
      );
      final s = scheduler.applyQuality(low, quality: 0, reviewedAtMs: _day);
      expect(s.easeFactor, 1.3);
    });

    test('Antwort mit Joker (quality 3) zählt als Erfolg, senkt aber Ease', () {
      final s = scheduler.applyQuality(Sm2State.initial(),
          quality: kQualityCorrectWithHint, reviewedAtMs: 0);
      expect(s.repetitions, 1);
      expect(s.intervalDays, 1);
      // 2.5 + (0.1 - 2*(0.08 + 2*0.02)) = 2.5 - 0.14 = 2.36.
      expect(s.easeFactor, closeTo(2.36, 1e-9));
    });
  });

  group('qualityFromAttempt', () {
    test('falsch → kQualityWrong (Fehlschlag-Schwelle)', () {
      expect(qualityFromAttempt(wasCorrect: false, hintUsed: false),
          kQualityWrong);
      expect(
          qualityFromAttempt(wasCorrect: false, hintUsed: true), kQualityWrong);
      expect(kQualityWrong, lessThan(3));
    });

    test('richtig mit Joker → kQualityCorrectWithHint', () {
      expect(qualityFromAttempt(wasCorrect: true, hintUsed: true),
          kQualityCorrectWithHint);
    });

    test('richtig ohne Joker → kQualityCorrect', () {
      expect(qualityFromAttempt(wasCorrect: true, hintUsed: false),
          kQualityCorrect);
    });
  });
}
