import 'dart:math';

import '../../../core/database/database.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_question.dart';
import 'quiz_builder.dart' show kQuizQuestionCount, kQuizOptionsPerQuestion;

const String kDailyLessonId = '__daily__';

int dailyDateKey(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

/// Baut 10 Quiz-Fragen für die „Quiz des Tages"-Karte. Seed = Datumsschlüssel
/// → alle Spieler bekommen am selben Tag dieselben Items, unabhängig von der
/// gewählten Richtung. Distractoren werden ebenfalls deterministisch aus
/// dem Gesamt-Pool gezogen.
class DailyQuizBuilder {
  DailyQuizBuilder(this._db);

  final AppDatabase _db;

  Future<List<QuizQuestion>> build({
    required DateTime date,
    required QuizDirection direction,
  }) async {
    final all = await _db.allItems();
    if (all.length < kQuizOptionsPerQuestion) return const [];

    final seed = dailyDateKey(date);
    final rng = Random(seed);
    final shuffled = [...all]..shuffle(rng);
    final picked = shuffled.take(kQuizQuestionCount).toList();

    return picked.map((item) {
      final correct = _answerFor(item, direction);
      final distractors = <String>{};
      // Eigene Shuffle-Instanz pro Frage, damit Distractor-Picks reproducierbar
      // sind und nicht von der äußeren Reihenfolge abhängen.
      final pool = [...all.where((i) => i.id != item.id)]..shuffle(rng);
      for (final c in pool) {
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
    return (ipa == null || ipa.isEmpty) ? null : ipa;
  }
}
