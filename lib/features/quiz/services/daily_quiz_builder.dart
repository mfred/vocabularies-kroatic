import 'dart:math';

import '../../../core/database/database.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_question.dart';
import 'daily_assignment.dart';
import 'quiz_builder.dart' show kQuizOptionsPerQuestion, QuizBuilder;

const String kDailyLessonId = '__daily__';

int dailyDateKey(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

/// Baut die Fragen fürs Quiz des Tages. Ab Iter 43 ist das Quiz **pro
/// Spieler** unterschiedlich — der Assignment-Service würfelt Mode + Bonus
/// für den Tag, und dieser Builder spielt den passenden Item-Pool.
class DailyQuizBuilder {
  DailyQuizBuilder(this._db);

  final AppDatabase _db;

  Future<List<QuizQuestion>> build({
    required DateTime date,
    required QuizDirection direction,
    required String playerId,
    required DailyAssignment assignment,
  }) async {
    final seed = dailyDateKey(date) * 1000 + (playerId.hashCode & 0x3FF);
    final rng = Random(seed);

    switch (assignment.mode) {
      case DailyMode.category:
        return QuizBuilder(_db, random: rng).build(
          lessonId: assignment.categoryLessonId!,
          playerId: playerId,
          direction: direction,
        );

      case DailyMode.newWords:
      case DailyMode.mistakes:
        final all = await _db.allItems();
        return _buildFromPool(
          pool: assignment.itemPool,
          allItems: all,
          direction: direction,
          rng: rng,
        );
    }
  }

  List<QuizQuestion> _buildFromPool({
    required List<Item> pool,
    required List<Item> allItems,
    required QuizDirection direction,
    required Random rng,
  }) {
    return pool.map((item) {
      final correct = _answerFor(item, direction);
      final candidates = [
        ...allItems.where((i) => i.id != item.id),
      ]..shuffle(rng);
      final distractors = <String>{};
      for (final c in candidates) {
        final ans = _answerFor(c, direction);
        if (ans == correct || distractors.contains(ans)) continue;
        distractors.add(ans);
        if (distractors.length == kQuizOptionsPerQuestion - 1) break;
      }
      final options = [correct, ...distractors]..shuffle(rng);
      return QuizQuestion(
        itemId: item.id,
        prompt: _promptFor(item, direction),
        correct: correct,
        options: options,
        ipaHint: _ipaFor(item, direction),
        isNewWord: false,
        direction: direction,
        difficulty: item.difficulty,
      );
    }).toList();
  }

  String _promptFor(Item item, QuizDirection direction) =>
      direction == QuizDirection.deToHr ? item.deText : item.hrText;

  String _answerFor(Item item, QuizDirection direction) =>
      direction == QuizDirection.deToHr ? item.hrText : item.deText;

  String? _ipaFor(Item item, QuizDirection direction) {
    final ipa = direction == QuizDirection.deToHr ? item.hrIpa : item.deIpa;
    return (ipa == null || ipa.trim().isEmpty) ? null : ipa;
  }
}
