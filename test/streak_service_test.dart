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

  group('Reward tiers', () {
    test('bonusForStreakDay liefert Wert für Meilensteine', () {
      expect(bonusForStreakDay(3), 50);
      expect(bonusForStreakDay(7), 150);
      expect(bonusForStreakDay(14), 400);
      expect(bonusForStreakDay(30), 1000);
    });

    test('Nicht-Meilensteine liefern null', () {
      expect(bonusForStreakDay(1), isNull);
      expect(bonusForStreakDay(5), isNull);
      expect(bonusForStreakDay(13), isNull);
    });
  });
}
