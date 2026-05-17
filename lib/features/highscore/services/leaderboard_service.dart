import '../../../core/database/database.dart';
import '../../quiz/models/quiz_direction.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_range.dart';

class LeaderboardService {
  LeaderboardService(this._db);

  final AppDatabase _db;

  Future<List<LeaderboardEntry>> top({
    required LeaderboardRange range,
    String? lessonId,
    int limit = 50,
  }) async {
    final bounds = range.boundsNow();
    final rows = await _db.topSessionsDetailed(
      sinceMs: bounds.sinceMs,
      untilMs: bounds.untilMs,
      lessonId: lessonId,
      limit: limit,
    );
    return List<LeaderboardEntry>.generate(rows.length, (i) {
      final row = rows[i];
      final s = row.session;
      return LeaderboardEntry(
        rank: i + 1,
        playerId: s.playerId,
        displayName: row.player?.displayName ?? '?',
        lessonId: s.lessonId,
        lessonTitle: row.lesson?.titleDe ?? s.lessonId,
        direction: _directionFromMode(s.mode),
        scorePoints: s.scorePoints,
        correctCount: s.correctCount,
        totalCount: s.totalCount,
        hintsUsed: s.hintsUsed,
        durationMs: s.durationMs ?? 0,
        finishedAt: DateTime.fromMillisecondsSinceEpoch(s.finishedAt ?? 0),
      );
    });
  }

  QuizDirection? _directionFromMode(String mode) {
    for (final d in QuizDirection.values) {
      if (d.mode == mode) return d;
    }
    return null;
  }
}
