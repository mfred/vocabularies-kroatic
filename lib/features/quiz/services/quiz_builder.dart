import 'dart:math';

import '../../../core/database/database.dart';
import '../models/item_attempt_stats.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_question.dart';
import 'quiz_selector.dart';
import 'vocab_icons.dart';

const int kQuizQuestionCount = 10;
const int kQuizOptionsPerQuestion = 4;

const Map<String, int> _kStageOrder = {
  'words': 0,
  'phrases': 1,
  'sentences': 2,
};

/// Stabil nach Stage sortieren — Wörter (0) vor Phrasen (1) vor Sätzen (2).
/// Unbekannte Stages landen hinten. Public, weil unit-getestet.
List<Item> sortByStage(List<Item> items) {
  return items
    ..sort((a, b) =>
        (_kStageOrder[a.stage] ?? 99).compareTo(_kStageOrder[b.stage] ?? 99));
}

class QuizBuilder {
  QuizBuilder(this._db, {Random? random}) : _random = random ?? Random();

  final AppDatabase _db;
  final Random _random;

  Future<List<QuizQuestion>> build({
    required String lessonId,
    required String playerId,
    required QuizDirection direction,
    List<Item>? itemPoolOverride,
  }) async {
    final items = await _db.itemsForLesson(lessonId);
    if (items.isEmpty) return const [];

    final stats = await _db.attemptStatsByItem(
      playerId: playerId,
      mode: direction.mode,
    );
    // Im Review-Modus wird die Frage-Auswahl auf den übergebenen Pool
    // beschränkt; Distractoren ziehen wir trotzdem aus der ganzen Lektion.
    final questionItems = itemPoolOverride ?? items;
    if (questionItems.isEmpty) return const [];
    // Stage-Sort nach der Auswahl: Wörter zuerst, dann Phrasen, dann Sätze —
    // damit es am Anfang nicht zu schwer losgeht. Innerhalb derselben Stage
    // bleibt die Reihenfolge des QuizSelectors (seenCount/difficulty) stabil.
    final picked = sortByStage(_pickQuestionItems(questionItems, stats));
    final seenIds = <String>{
      for (final e in stats.entries)
        if (e.value.seenCount > 0) e.key,
    };

    return picked.map((item) {
      final isNew = !seenIds.contains(item.id);
      final correct = _answerFor(item, direction);
      final distractors = _pickDistractors(
        all: items,
        question: item,
        correctAnswer: correct,
        direction: direction,
      );
      final options = [correct, ...distractors]..shuffle(_random);
      return QuizQuestion(
        itemId: item.id,
        prompt: _promptFor(item, direction),
        correct: correct,
        options: options,
        ipaHint: _ipaFor(item, direction),
        pictureIcon: VocabIcons.lookup(item.hrText),
        isNewWord: isNew,
        direction: direction,
        difficulty: item.difficulty,
      );
    }).toList();
  }

  String? _ipaFor(Item item, QuizDirection direction) {
    final ipa =
        direction == QuizDirection.deToHr ? item.hrIpa : item.deIpa;
    if (ipa == null || ipa.isEmpty) return null;
    return ipa;
  }

  List<Item> _pickQuestionItems(
    List<Item> all,
    Map<String, ItemAttemptStats> stats,
  ) {
    final words = all.where((i) => i.stage == 'words').toList();
    final phrases = all.where((i) => i.stage == 'phrases').toList();
    final sentences = all.where((i) => i.stage == 'sentences').toList();
    final stagePool = <Item>[...words, ...phrases, ...sentences];
    return QuizSelector.pick(
      items: stagePool,
      stats: stats,
      count: kQuizQuestionCount,
    );
  }

  List<String> _pickDistractors({
    required List<Item> all,
    required Item question,
    required String correctAnswer,
    required QuizDirection direction,
  }) {
    final sameStage = all
        .where((i) => i.id != question.id && i.stage == question.stage)
        .toList()
      ..shuffle(_random);
    final otherStages = all
        .where((i) => i.id != question.id && i.stage != question.stage)
        .toList()
      ..shuffle(_random);

    final picked = <String>{};
    for (final candidate in [...sameStage, ...otherStages]) {
      final ans = _answerFor(candidate, direction);
      if (ans == correctAnswer) continue;
      if (picked.contains(ans)) continue;
      picked.add(ans);
      if (picked.length == kQuizOptionsPerQuestion - 1) break;
    }
    return picked.toList();
  }

  String _promptFor(Item item, QuizDirection direction) {
    return direction == QuizDirection.deToHr ? item.deText : item.hrText;
  }

  String _answerFor(Item item, QuizDirection direction) {
    return direction == QuizDirection.deToHr ? item.hrText : item.deText;
  }

}
