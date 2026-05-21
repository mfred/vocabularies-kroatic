import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/streaks/models/streak_reward.dart';
import 'package:vocabularies_kroatic/features/streaks/services/streak_service.dart';

int _ms(int year, int month, int day, [int hour = 12]) =>
    DateTime(year, month, day, hour).millisecondsSinceEpoch;

void main() {
  group('StreakService.computeCurrentStreak', () {
    final now = DateTime(2026, 5, 18, 10);

    test('leere Historie -> 0', () {
      expect(StreakService.computeCurrentStreak([], now), 0);
    });

    test('nur heute gespielt -> 1', () {
      expect(
        StreakService.computeCurrentStreak([_ms(2026, 5, 18)], now),
        1,
      );
    });

    test('3 Tage in Folge bis heute -> 3', () {
      expect(
        StreakService.computeCurrentStreak(
          [_ms(2026, 5, 18), _ms(2026, 5, 17), _ms(2026, 5, 16)],
          now,
        ),
        3,
      );
    });

    test('heute nichts, aber gestern -> Streak läuft weiter (Tagestoleranz)',
        () {
      expect(
        StreakService.computeCurrentStreak(
          [_ms(2026, 5, 17), _ms(2026, 5, 16)],
          now,
        ),
        2,
      );
    });

    test('Lücke vorgestern -> Bruch, nur gestern zählt', () {
      expect(
        StreakService.computeCurrentStreak(
          [_ms(2026, 5, 17), _ms(2026, 5, 15)],
          now,
        ),
        1,
      );
    });

    test('mehrere Sessions am selben Tag zählen als 1 Tag', () {
      expect(
        StreakService.computeCurrentStreak(
          [
            _ms(2026, 5, 18, 9),
            _ms(2026, 5, 18, 14),
            _ms(2026, 5, 17, 18),
          ],
          now,
        ),
        2,
      );
    });

    test('weder heute noch gestern -> 0', () {
      expect(
        StreakService.computeCurrentStreak(
          [_ms(2026, 5, 16), _ms(2026, 5, 15)],
          now,
        ),
        0,
      );
    });
  });

  group('StreakService.computeLongestStreak', () {
    test('leere Historie -> 0', () {
      expect(StreakService.computeLongestStreak([]), 0);
    });

    test('ein Tag -> 1', () {
      expect(StreakService.computeLongestStreak([_ms(2026, 5, 18)]), 1);
    });

    test('längste Sequenz wird gefunden', () {
      final history = [
        _ms(2026, 5, 1),
        _ms(2026, 5, 2),
        _ms(2026, 5, 3),
        _ms(2026, 5, 10),
        _ms(2026, 5, 11),
        _ms(2026, 5, 15),
      ];
      expect(StreakService.computeLongestStreak(history), 3);
    });
  });

  group('Reward tiers (Skala x20)', () {
    test('bonusForStreakDay liefert Wert für Meilensteine', () {
      expect(bonusForStreakDay(3), 3);
      expect(bonusForStreakDay(7), 50); // saftiger 7-Tage-Bonus
      expect(bonusForStreakDay(14), 30);
      expect(bonusForStreakDay(30), 100);
      expect(bonusForStreakDay(60), 200);
      expect(bonusForStreakDay(100), 500);
    });

    test('Nicht-Meilensteine liefern null', () {
      expect(bonusForStreakDay(1), isNull);
      expect(bonusForStreakDay(5), isNull);
      expect(bonusForStreakDay(13), isNull);
    });
  });

  group('StreakService.computeCurrentStreakWithSavers', () {
    final now = DateTime(2026, 5, 18, 10);

    test('Lücke heute, gestern auch leer, Saver vorhanden → Saver greift',
        () {
      // Vorgestern + Tage davor gespielt; gestern + heute leer.
      final result = StreakService.computeCurrentStreakWithSavers(
        [
          _ms(2026, 5, 16),
          _ms(2026, 5, 15),
          _ms(2026, 5, 14),
        ],
        now,
        1,
      );
      // Toleranz heute → cursor=gestern (leer) → cursor=vorgestern (Saver
      // konsumiert ist NICHT korrekt im Toleranz-Pfad). Tatsächlich startet
      // die Zählung bei 16.5. (3 Tage in Folge).
      expect(result.streak, 3);
      expect(result.consumed, 1);
    });

    test('Lücke mittendrin, 1 Saver → Saver überbrückt eine Lücke', () {
      // heute (18), gestern (17) leer, vorgestern (16) gespielt, dann
      // 15.+14.+13. ebenfalls gespielt.
      final result = StreakService.computeCurrentStreakWithSavers(
        [
          _ms(2026, 5, 18),
          _ms(2026, 5, 16),
          _ms(2026, 5, 15),
          _ms(2026, 5, 14),
          _ms(2026, 5, 13),
        ],
        now,
        1,
      );
      // heute zählt → Saver für 17. → 16/15/14/13 alle gespielt → Streak 5.
      expect(result.streak, 5);
      expect(result.consumed, 1);
    });

    test('Zwei Lücken hintereinander, 1 Saver → Saver greift nur einmal',
        () {
      // heute (18), 17 leer, 16 leer, 15 gespielt
      final result = StreakService.computeCurrentStreakWithSavers(
        [_ms(2026, 5, 18), _ms(2026, 5, 15), _ms(2026, 5, 14)],
        now,
        1,
      );
      // heute → Saver für 17 → 16 wieder Lücke → Streak bricht hier
      expect(result.streak, 1);
      expect(result.consumed, 1);
    });

    test('Saver = 0 → reine natürliche Streak-Berechnung', () {
      final result = StreakService.computeCurrentStreakWithSavers(
        [_ms(2026, 5, 18), _ms(2026, 5, 17), _ms(2026, 5, 16)],
        now,
        0,
      );
      expect(result.streak, 3);
      expect(result.consumed, 0);
    });
  });
}
