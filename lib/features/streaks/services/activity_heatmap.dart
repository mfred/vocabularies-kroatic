/// Aktivitäts-Heatmap (GitHub-Stil): faltet die Session-Abschluss-Zeitstempel
/// deterministisch zu Tages-Zählern über die letzten [weeks] Wochen.
///
/// Wie der Streak (siehe `StreakService`) liest die Heatmap dieselbe
/// `quiz_attempts`/Session-Historie — keine zweite Quelle der Wahrheit. Die
/// reine Faltung ist hier ausgelagert, damit sie ohne DB/Flutter testbar ist.
library;

/// Ergebnis der Heatmap-Faltung. Spalten = Wochen (älteste links, „heute" in
/// der letzten Spalte), Zeilen = Wochentage (Mo = 0 … So = 6).
class ActivityHeatmap {
  const ActivityHeatmap({
    required this.weeks,
    required this.cells,
    required this.maxCount,
    required this.activeDays,
    required this.totalSessions,
  });

  /// Anzahl der Wochen-Spalten.
  final int weeks;

  /// `cells[week][weekday]` mit weekday 0 = Montag … 6 = Sonntag.
  /// `null` markiert Tage außerhalb des Fensters (in der Zukunft nach „heute").
  final List<List<int?>> cells;

  /// Höchster Tageszähler im Fenster (für die Farbskalierung). 0 wenn leer.
  final int maxCount;

  /// Anzahl Tage mit mindestens einer abgeschlossenen Session im Fenster.
  final int activeDays;

  /// Summe aller abgeschlossenen Sessions im Fenster.
  final int totalSessions;

  bool get isEmpty => totalSessions == 0;
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Addiert [days] Tage über den Konstruktor (DST-sicher, anders als
/// `Duration(days:)`, das über Sommerzeit-Grenzen verrutschen kann).
DateTime _addDays(DateTime base, int days) =>
    DateTime(base.year, base.month, base.day + days);

/// Faltet [finishedAtsMs] (Millisekunden-Zeitstempel abgeschlossener Sessions)
/// relativ zu [now] in ein Wochen-×-Wochentag-Raster über die letzten [weeks]
/// Wochen. Die letzte Spalte endet in der Woche, die „heute" enthält; künftige
/// Tage dieser Woche sind `null`.
ActivityHeatmap buildActivityHeatmap(
  List<int> finishedAtsMs,
  DateTime now, {
  int weeks = 13,
}) {
  assert(weeks > 0);
  final counts = <int, int>{};
  for (final ms in finishedAtsMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final key = _dayKey(DateTime(d.year, d.month, d.day));
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final today = DateTime(now.year, now.month, now.day);
  final todayKey = _dayKey(today);
  // weekday: Mo = 1 … So = 7 → Spalten-Index Mo = 0.
  final todayCol = today.weekday - 1;
  // Montag der ersten sichtbaren Woche.
  final start = _addDays(today, -(todayCol + (weeks - 1) * 7));

  final cells = <List<int?>>[];
  var maxCount = 0;
  var activeDays = 0;
  var totalSessions = 0;
  for (var w = 0; w < weeks; w++) {
    final col = <int?>[];
    for (var d = 0; d < 7; d++) {
      final date = _addDays(start, w * 7 + d);
      if (_dayKey(date) > todayKey) {
        col.add(null);
        continue;
      }
      final c = counts[_dayKey(date)] ?? 0;
      col.add(c);
      if (c > 0) {
        activeDays++;
        totalSessions += c;
        if (c > maxCount) maxCount = c;
      }
    }
    cells.add(col);
  }

  return ActivityHeatmap(
    weeks: weeks,
    cells: cells,
    maxCount: maxCount,
    activeDays: activeDays,
    totalSessions: totalSessions,
  );
}
