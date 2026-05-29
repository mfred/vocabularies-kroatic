import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/streaks/services/activity_heatmap.dart';

int _ms(int year, int month, int day, [int hour = 12]) =>
    DateTime(year, month, day, hour).millisecondsSinceEpoch;

void main() {
  group('buildActivityHeatmap', () {
    // Donnerstag.
    final now = DateTime(2026, 5, 28, 10);

    test('leere Historie -> alles 0/leer', () {
      final h = buildActivityHeatmap([], now);
      expect(h.weeks, 13);
      expect(h.cells.length, 13);
      expect(h.maxCount, 0);
      expect(h.activeDays, 0);
      expect(h.totalSessions, 0);
      expect(h.isEmpty, isTrue);
    });

    test('Raster ist 13 Wochen × 7 Tage', () {
      final h = buildActivityHeatmap([], now);
      for (final col in h.cells) {
        expect(col.length, 7);
      }
    });

    test('künftige Tage der laufenden Woche sind null', () {
      final h = buildActivityHeatmap([], now);
      final lastWeek = h.cells.last;
      // now = Donnerstag (weekday 4) -> Index 3. Mo..Do gesetzt, Fr..So null.
      expect(lastWeek[0], isNotNull); // Mo
      expect(lastWeek[3], isNotNull); // Do = heute
      expect(lastWeek[4], isNull); // Fr
      expect(lastWeek[5], isNull); // Sa
      expect(lastWeek[6], isNull); // So
    });

    test('heute landet in der letzten Spalte mit korrektem Zähler', () {
      final h = buildActivityHeatmap(
        [_ms(2026, 5, 28), _ms(2026, 5, 28, 18)],
        now,
      );
      expect(h.cells.last[3], 2); // Donnerstag, 2 Sessions
      expect(h.totalSessions, 2);
      expect(h.activeDays, 1);
      expect(h.maxCount, 2);
    });

    test('mehrere Tage werden korrekt gezählt', () {
      final h = buildActivityHeatmap(
        [
          _ms(2026, 5, 28), // Do (heute)
          _ms(2026, 5, 27), // Mi
          _ms(2026, 5, 27, 9), // Mi (zweite Session)
          _ms(2026, 5, 25), // Mo
        ],
        now,
      );
      expect(h.totalSessions, 4);
      expect(h.activeDays, 3);
      expect(h.maxCount, 2); // Mi hatte 2
      final lastWeek = h.cells.last;
      expect(lastWeek[3], 1); // Do
      expect(lastWeek[2], 2); // Mi
      expect(lastWeek[0], 1); // Mo
      expect(lastWeek[1], 0); // Di leer
    });

    test('Sessions außerhalb des 13-Wochen-Fensters fallen heraus', () {
      // ~20 Wochen zurück -> nicht im Raster.
      final old = _ms(2026, 1, 1);
      final h = buildActivityHeatmap([old], now);
      expect(h.totalSessions, 0);
      expect(h.isEmpty, isTrue);
    });

    test('benutzerdefinierte Wochenanzahl', () {
      final h = buildActivityHeatmap([], now, weeks: 4);
      expect(h.weeks, 4);
      expect(h.cells.length, 4);
    });
  });
}
