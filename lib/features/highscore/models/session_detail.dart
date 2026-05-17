import '../../quiz/models/joker_type.dart';
import '../../quiz/models/quiz_direction.dart';

class AttemptDetail {
  const AttemptDetail({
    required this.questionOrder,
    required this.wasCorrect,
    required this.hintUsed,
    required this.jokers,
    required this.responseMs,
    required this.pickedOption,
    required this.itemId,
    required this.deText,
    required this.hrText,
  });

  final int questionOrder;
  final bool wasCorrect;
  final bool hintUsed;
  final List<JokerType> jokers;
  final int responseMs;
  final String? pickedOption;
  final String itemId;
  final String? deText;
  final String? hrText;

  String? promptFor(QuizDirection? d) {
    if (d == QuizDirection.deToHr) return deText;
    if (d == QuizDirection.hrToDe) return hrText;
    return deText ?? hrText;
  }

  String? answerFor(QuizDirection? d) {
    if (d == QuizDirection.deToHr) return hrText;
    if (d == QuizDirection.hrToDe) return deText;
    return hrText ?? deText;
  }
}

class SessionDetail {
  const SessionDetail({
    required this.sessionId,
    required this.lessonId,
    required this.lessonTitle,
    required this.direction,
    required this.startedAt,
    required this.finishedAt,
    required this.durationMs,
    required this.correctCount,
    required this.totalCount,
    required this.hintsUsed,
    required this.scorePoints,
    required this.attempts,
  });

  final String sessionId;
  final String lessonId;
  final String lessonTitle;
  final QuizDirection? direction;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int durationMs;
  final int correctCount;
  final int totalCount;
  final int hintsUsed;
  final int scorePoints;
  final List<AttemptDetail> attempts;
}
