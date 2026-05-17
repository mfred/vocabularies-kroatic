import 'dart:convert';

import '../../../core/database/database.dart';
import '../../quiz/models/joker_type.dart';
import '../../quiz/models/quiz_direction.dart';
import '../models/session_detail.dart';

class SessionDetailService {
  SessionDetailService(this._db);

  final AppDatabase _db;

  Future<SessionDetail?> load(String sessionId) async {
    final session = await _db.getQuizSession(sessionId);
    if (session == null) return null;
    final lesson = await _db.getLessonCache(session.lessonId);
    final rows = await _db.attemptsWithItemForSession(sessionId);
    final direction = _directionFromMode(session.mode);

    final attempts = rows
        .map((r) => AttemptDetail(
              questionOrder: r.attempt.questionOrder,
              wasCorrect: r.attempt.wasCorrect,
              hintUsed: r.attempt.hintUsed,
              jokers: _decodeJokers(r.attempt.jokersJson),
              responseMs: r.attempt.responseMs,
              pickedOption: r.attempt.pickedOption,
              itemId: r.attempt.itemId,
              deText: r.item?.deText,
              hrText: r.item?.hrText,
            ))
        .toList();

    return SessionDetail(
      sessionId: session.id,
      lessonId: session.lessonId,
      lessonTitle: lesson?.titleDe ?? session.lessonId,
      direction: direction,
      startedAt: DateTime.fromMillisecondsSinceEpoch(session.startedAt),
      finishedAt: session.finishedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(session.finishedAt!),
      durationMs: session.durationMs ?? 0,
      correctCount: session.correctCount,
      totalCount: session.totalCount,
      hintsUsed: session.hintsUsed,
      scorePoints: session.scorePoints,
      attempts: attempts,
    );
  }

  List<JokerType> _decodeJokers(String? jokersJson) {
    if (jokersJson == null || jokersJson.isEmpty) return const [];
    try {
      final list = jsonDecode(jokersJson) as List;
      return list
          .map((e) => JokerType.fromCode(e as String))
          .whereType<JokerType>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  QuizDirection? _directionFromMode(String mode) {
    for (final d in QuizDirection.values) {
      if (mode == d.code || mode.endsWith('_${d.code}')) return d;
    }
    return null;
  }
}
