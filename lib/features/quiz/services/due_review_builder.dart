import 'dart:math';

import '../../../core/database/database.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_question.dart';
import 'daily_quiz_builder.dart' show buildPoolQuestions;
import 'quiz_builder.dart' show kQuizQuestionCount;

/// Stellt die „Fällige Wiederholung" zusammen: lektionsübergreifend alle Items,
/// deren aus der Attempt-Historie gefalteter SM-2-Fälligkeitszeitpunkt erreicht
/// ist. Items, die noch nie beantwortet wurden, sind nicht fällig (die zählen
/// als „neu" und laufen über das Quiz des Tages).
class DueReviewBuilder {
  DueReviewBuilder(this._db, {Random? random}) : _random = random ?? Random();

  final AppDatabase _db;
  final Random _random;

  Future<List<Item>> dueItems({
    required String playerId,
    required QuizDirection direction,
    required int asOfMs,
    int max = kQuizQuestionCount,
  }) async {
    final states =
        await _db.sm2StatesByItem(playerId: playerId, mode: direction.mode);
    final due = states.entries
        .where((e) => e.value.dueAtMs <= asOfMs)
        .toList()
      // Überfälligste zuerst.
      ..sort((a, b) => a.value.dueAtMs.compareTo(b.value.dueAtMs));
    if (due.isEmpty) return const [];

    final byId = {for (final it in await _db.allItems()) it.id: it};
    final out = <Item>[];
    for (final e in due) {
      final it = byId[e.key];
      if (it != null) out.add(it);
      if (out.length >= max) break;
    }
    return out;
  }

  Future<int> dueCount({
    required String playerId,
    required QuizDirection direction,
    required int asOfMs,
  }) async {
    final states =
        await _db.sm2StatesByItem(playerId: playerId, mode: direction.mode);
    var n = 0;
    for (final s in states.values) {
      if (s.dueAtMs <= asOfMs) n++;
    }
    return n;
  }

  Future<List<QuizQuestion>> build({
    required String playerId,
    required QuizDirection direction,
    required int asOfMs,
  }) async {
    final pool = await dueItems(
      playerId: playerId,
      direction: direction,
      asOfMs: asOfMs,
    );
    if (pool.isEmpty) return const [];
    return buildPoolQuestions(
      pool: pool,
      allItems: await _db.allItems(),
      direction: direction,
      rng: _random,
    );
  }
}
