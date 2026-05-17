import '../../quiz/models/quiz_direction.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.sessionId,
    required this.playerId,
    required this.displayName,
    required this.lessonId,
    required this.lessonTitle,
    required this.direction,
    required this.scorePoints,
    required this.correctCount,
    required this.totalCount,
    required this.hintsUsed,
    required this.durationMs,
    required this.finishedAt,
  });

  final int rank;
  final String sessionId;
  final String playerId;
  final String displayName;
  final String lessonId;
  final String lessonTitle;
  final QuizDirection? direction;
  final int scorePoints;
  final int correctCount;
  final int totalCount;
  final int hintsUsed;
  final int durationMs;
  final DateTime finishedAt;
}
