import 'package:drift/drift.dart';

import '../../../core/database/database.dart' hide StreakReward;

class PlayerStats {
  const PlayerStats({
    required this.totalSessions,
    required this.sessionsThisWeek,
    required this.correctCount,
    required this.totalCount,
    required this.favouriteLessonTitle,
    required this.favouriteLessonSessions,
  });

  final int totalSessions;
  final int sessionsThisWeek;
  final int correctCount;
  final int totalCount;
  final String? favouriteLessonTitle;
  final int favouriteLessonSessions;

  double get correctRatio =>
      totalCount == 0 ? 0.0 : correctCount / totalCount;
  int get correctRatioPercent => (correctRatio * 100).round();

  bool get hasAnySession => totalSessions > 0;
}

class PlayerStatsService {
  PlayerStatsService(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<PlayerStats> load(String playerId) async {
    final now = _clock();
    final weekStart = _mondayOfWeek(now).millisecondsSinceEpoch;

    final totalRow = await (_db.selectOnly(_db.quizSessions)
          ..addColumns([
            _db.quizSessions.id.count(),
            _db.quizSessions.correctCount.sum(),
            _db.quizSessions.totalCount.sum(),
          ])
          ..where(_db.quizSessions.playerId.equals(playerId) &
              _db.quizSessions.finishedAt.isNotNull()))
        .getSingle();
    final total = totalRow.read(_db.quizSessions.id.count()) ?? 0;
    final correct = totalRow.read(_db.quizSessions.correctCount.sum()) ?? 0;
    final totalAttempts = totalRow.read(_db.quizSessions.totalCount.sum()) ?? 0;

    final weekRow = await (_db.selectOnly(_db.quizSessions)
          ..addColumns([_db.quizSessions.id.count()])
          ..where(_db.quizSessions.playerId.equals(playerId) &
              _db.quizSessions.finishedAt
                  .isBiggerOrEqualValue(weekStart)))
        .getSingle();
    final weekCount = weekRow.read(_db.quizSessions.id.count()) ?? 0;

    // Lieblings-Lektion: häufigster lessonId, der nicht der Daily-Sentinel ist.
    final favRows = await (_db.customSelect(
      '''
SELECT lesson_id, COUNT(*) AS c
FROM quiz_sessions
WHERE player_id = ?1 AND finished_at IS NOT NULL
  AND lesson_id != '__daily__'
GROUP BY lesson_id
ORDER BY c DESC
LIMIT 1
''',
      variables: [Variable.withString(playerId)],
      readsFrom: {_db.quizSessions},
    )).get();
    String? favTitle;
    int favSessions = 0;
    if (favRows.isNotEmpty) {
      final favLessonId = favRows.first.read<String>('lesson_id');
      favSessions = favRows.first.read<int>('c');
      final cache = await _db.getLessonCache(favLessonId);
      favTitle = cache?.titleDe ?? favLessonId;
    }

    return PlayerStats(
      totalSessions: total,
      sessionsThisWeek: weekCount,
      correctCount: correct,
      totalCount: totalAttempts,
      favouriteLessonTitle: favTitle,
      favouriteLessonSessions: favSessions,
    );
  }

  /// Montag 00:00:00 lokal in der laufenden Woche.
  static DateTime _mondayOfWeek(DateTime now) {
    final days = now.weekday - DateTime.monday; // Mo=1 → 0, So=7 → 6
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
  }
}
