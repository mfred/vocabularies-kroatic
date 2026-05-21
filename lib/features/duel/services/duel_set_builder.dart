import 'dart:math';

import '../../../core/database/database.dart';
import '../../quiz/models/quiz_direction.dart';
import '../../quiz/services/quiz_builder.dart' show sortByStage;
import '../models/duel_pair.dart';

const int kDuelRoundCount = 3;
const int kDuelPairsPerRoundPreferred = 5;
const int kDuelPairsPerRoundFallback = 4;
const int kDuelMinLessonItems =
    kDuelRoundCount * kDuelPairsPerRoundFallback; // = 12

/// Generiert genau [kDuelRoundCount] Runden mit je 4–5 Paaren aus einer
/// Lektion. Identisch für beide Duell-Teilnehmer, wenn dasselbe `rng` (bzw.
/// derselbe persistierte Output) verwendet wird.
class DuelSetBuilder {
  DuelSetBuilder(this._db);

  final AppDatabase _db;

  /// Liefert null wenn die Lektion zu wenige Items hat (< [kDuelMinLessonItems]).
  Future<List<DuelRound>?> build({
    required String lessonId,
    required QuizDirection direction,
    Random? random,
  }) async {
    final rng = random ?? Random();
    final items = await _db.itemsForLesson(lessonId);
    if (items.length < kDuelMinLessonItems) return null;

    final pool = sortByStage([...items])..shuffle(rng);
    final perRound = pool.length >= kDuelRoundCount * kDuelPairsPerRoundPreferred
        ? kDuelPairsPerRoundPreferred
        : kDuelPairsPerRoundFallback;

    final rounds = <DuelRound>[];
    for (var r = 0; r < kDuelRoundCount; r++) {
      final slice = pool.sublist(r * perRound, (r + 1) * perRound);
      final pairs =
          slice.map((it) => _toPair(it, direction)).toList(growable: false);
      final ids = [for (final p in pairs) p.itemId]..shuffle(rng);
      rounds.add(DuelRound(pairs: pairs, rightOrder: ids));
    }
    return rounds;
  }

  DuelPair _toPair(Item item, QuizDirection direction) {
    final left =
        direction == QuizDirection.deToHr ? item.deText : item.hrText;
    final right =
        direction == QuizDirection.deToHr ? item.hrText : item.deText;
    return DuelPair(itemId: item.id, leftText: left, rightText: right);
  }
}
