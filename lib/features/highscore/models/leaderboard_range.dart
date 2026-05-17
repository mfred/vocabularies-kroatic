enum LeaderboardRange {
  today('Heute'),
  week('Woche'),
  month('Monat'),
  allTime('Ewig');

  const LeaderboardRange(this.label);

  final String label;

  ({int sinceMs, int untilMs}) boundsNow([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final untilMs = reference.millisecondsSinceEpoch;
    final DateTime start;
    switch (this) {
      case LeaderboardRange.today:
        start = DateTime(reference.year, reference.month, reference.day);
        break;
      case LeaderboardRange.week:
        final monday =
            reference.subtract(Duration(days: reference.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day);
        break;
      case LeaderboardRange.month:
        start = DateTime(reference.year, reference.month, 1);
        break;
      case LeaderboardRange.allTime:
        start = DateTime.fromMillisecondsSinceEpoch(0);
        break;
    }
    return (sinceMs: start.millisecondsSinceEpoch, untilMs: untilMs);
  }
}
