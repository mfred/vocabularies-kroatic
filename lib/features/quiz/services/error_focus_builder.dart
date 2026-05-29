import 'dart:math';

import '../../../core/database/database.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_question.dart';
import 'daily_quiz_builder.dart' show buildPoolQuestions;
import 'quiz_builder.dart' show kQuizQuestionCount;

/// Stellt den „Fehlerfokus" zusammen: lektionsübergreifend die Items mit der
/// höchsten errorRate (`errors / (errors + successes + 1)`, siehe PROJECT.md
/// §2.4) — gezieltes Konsolidieren der fehleranfälligsten Vokabeln. Spiegelt
/// die Struktur von [DueReviewBuilder], zieht den Pool aber aus der kumulierten
/// Fehler-Statistik statt aus der SM-2-Fälligkeit.
///
/// Die Frage-Auswahl ist bewusst auf [kQuizQuestionCount] (10) begrenzt — wie
/// jede andere Session der App; PROJECT.md nennt „Top-30", die App standardi-
/// siert aber auf 10-Fragen-Sessions, daher nehmen wir die 10 härtesten.
class ErrorFocusBuilder {
  ErrorFocusBuilder(this._db, {Random? random}) : _random = random ?? Random();

  final AppDatabase _db;
  final Random _random;

  /// Die [max] härtesten noch existierenden Items, härtestes zuerst.
  /// Items, deren ID inzwischen „verbrannt" ist (nicht mehr in `items`),
  /// fallen still raus.
  Future<List<Item>> hardItems({
    required String playerId,
    int max = kQuizQuestionCount,
  }) async {
    final stats = await _db.itemErrorStats(playerId);
    if (stats.isEmpty) return const [];
    final byId = {for (final it in await _db.allItems()) it.id: it};
    final out = <Item>[];
    for (final s in stats) {
      final it = byId[s.itemId];
      if (it != null) out.add(it);
      if (out.length >= max) break;
    }
    return out;
  }

  /// Anzahl der Items mit mindestens einem Fehlversuch, die noch existieren.
  Future<int> hardCount({required String playerId}) async {
    final stats = await _db.itemErrorStats(playerId);
    if (stats.isEmpty) return 0;
    final ids = (await _db.allItems()).map((i) => i.id).toSet();
    return stats.where((s) => ids.contains(s.itemId)).length;
  }

  Future<List<QuizQuestion>> build({
    required String playerId,
    required QuizDirection direction,
  }) async {
    final pool = await hardItems(playerId: playerId);
    if (pool.isEmpty) return const [];
    return buildPoolQuestions(
      pool: pool,
      allItems: await _db.allItems(),
      direction: direction,
      rng: _random,
    );
  }
}
