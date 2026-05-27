import 'dart:math';

import '../../../core/database/database.dart' hide StreakReward;
import 'daily_quiz_builder.dart' show dailyDateKey;

/// Anzahl Fragen für den „5 neue Vokabeln"-Modus.
const int kDailyNewWordsCount = 5;

/// Min. Items, die für den Mistakes-Modus vorliegen müssen — sonst Fallback
/// zu Category.
const int kDailyMistakesMin = 4;

/// Min. Items in einer Lektion, damit sie als Category-Quiz herhalten darf.
const int kDailyCategoryMinItems = 12;

enum DailyMode { newWords, mistakes, category }

enum DailyBonus { flat30, doubleNext, streakSaver, multiplier15 }

class DailyAssignment {
  const DailyAssignment({
    required this.mode,
    required this.bonus,
    required this.itemPool,
    this.categoryLessonId,
    this.categoryLessonTitleDe,
  });

  final DailyMode mode;
  final DailyBonus bonus;

  /// Bei `newWords`/`mistakes`: die Items, aus denen die Fragen kommen.
  /// Bei `category` leer — der QuizBuilder zieht selbst aus der Lektion.
  final List<Item> itemPool;

  final String? categoryLessonId;
  final String? categoryLessonTitleDe;

  int get questionCount {
    switch (mode) {
      case DailyMode.newWords:
        return kDailyNewWordsCount;
      case DailyMode.mistakes:
      case DailyMode.category:
        return 10;
    }
  }
}

class DailyAssigner {
  DailyAssigner(this._db);

  final AppDatabase _db;

  int _seedFor(DateTime date, String playerId) =>
      dailyDateKey(date) * 1000 + (playerId.hashCode & 0x3FF);

  Future<DailyAssignment?> assignFor({
    required DateTime date,
    required String playerId,
  }) async {
    final seed = _seedFor(date, playerId);
    final rng = Random(seed);
    final modePick = rng.nextInt(DailyMode.values.length);
    final bonusPick = rng.nextInt(DailyBonus.values.length);
    final mode = DailyMode.values[modePick];
    final bonus = DailyBonus.values[bonusPick];

    // Pool-Aufbau mit ggf. Fallback zu category.
    switch (mode) {
      case DailyMode.newWords:
        final all = await _db.allItems();
        final seenDeHr = await _db.seenItemIdsForPlayer(
            playerId: playerId, mode: 'de_hr');
        final seenHrDe = await _db.seenItemIdsForPlayer(
            playerId: playerId, mode: 'hr_de');
        final seen = {...seenDeHr, ...seenHrDe};
        final unseen = all.where((i) => !seen.contains(i.id)).toList()
          ..shuffle(rng);
        if (unseen.length >= kDailyNewWordsCount) {
          return DailyAssignment(
            mode: DailyMode.newWords,
            bonus: bonus,
            itemPool: unseen.take(kDailyNewWordsCount).toList(),
          );
        }
        return _categoryAssignment(rng: rng, bonus: bonus);

      case DailyMode.mistakes:
        final lessons = await _db.allLessonsByOrder();
        final wrong = <Item>[];
        final seenIds = <String>{};
        for (final l in lessons) {
          final items = await _db.wrongItemsForLesson(
              playerId: playerId, lessonId: l.lessonId);
          for (final it in items) {
            if (seenIds.add(it.id)) wrong.add(it);
          }
        }
        if (wrong.length >= kDailyMistakesMin) {
          wrong.shuffle(rng);
          return DailyAssignment(
            mode: DailyMode.mistakes,
            bonus: bonus,
            itemPool: wrong.take(10).toList(),
          );
        }
        return _categoryAssignment(rng: rng, bonus: bonus);

      case DailyMode.category:
        return _categoryAssignment(rng: rng, bonus: bonus);
    }
  }

  Future<DailyAssignment?> _categoryAssignment({
    required Random rng,
    required DailyBonus bonus,
  }) async {
    final lessons = await _db.allLessonsByOrder();
    final eligible = <LessonsCacheData>[];
    for (final l in lessons) {
      final count = l.wordCount + l.phraseCount + l.sentenceCount;
      if (count >= kDailyCategoryMinItems) eligible.add(l);
    }
    if (eligible.isEmpty) return null;
    final pick = eligible[rng.nextInt(eligible.length)];
    return DailyAssignment(
      mode: DailyMode.category,
      bonus: bonus,
      itemPool: const [],
      categoryLessonId: pick.lessonId,
      categoryLessonTitleDe: pick.titleDe,
    );
  }
}

/// Anzeige-Texte für die Daily-Karte und das Pop-up.
extension DailyModeDisplay on DailyMode {
  String get emoji {
    switch (this) {
      case DailyMode.newWords:
        return '🆕';
      case DailyMode.mistakes:
        return '🛠️';
      case DailyMode.category:
        return '🎯';
    }
  }

  String get shortLabel {
    switch (this) {
      case DailyMode.newWords:
        return '$kDailyNewWordsCount neue Vokabeln';
      case DailyMode.mistakes:
        return 'Deine Fehler';
      case DailyMode.category:
        return 'Quiz einer Kategorie';
    }
  }

  String get description {
    switch (this) {
      case DailyMode.newWords:
        return 'Heute lernst du $kDailyNewWordsCount neue Vokabeln, die du noch nie gesehen hast.';
      case DailyMode.mistakes:
        return 'Wiederhole bis zu 10 Wörter, die du zuletzt falsch hattest.';
      case DailyMode.category:
        return 'Ein normales 10er-Quiz aus einer per Zufall gewählten Lektion.';
    }
  }
}

extension DailyBonusDisplay on DailyBonus {
  String get emoji => '🎁';

  String get shortLabel {
    switch (this) {
      case DailyBonus.flat30:
        return '+30 Bonuspunkte';
      case DailyBonus.doubleNext:
        return 'Nächstes Quiz zählt ×2';
      case DailyBonus.streakSaver:
        return '+1 Streak-Schoner';
      case DailyBonus.multiplier15:
        return 'Tages-Score ×1.5';
    }
  }

  String get description {
    switch (this) {
      case DailyBonus.flat30:
        return 'Beim Quiz-Abschluss bekommst du 30 Bonuspunkte direkt auf deinen Score.';
      case DailyBonus.doubleNext:
        return 'Dein nächstes reguläres Quiz wird mit doppelten Punkten gewertet.';
      case DailyBonus.streakSaver:
        return 'Du bekommst einen Streak-Schoner in dein Reservoir (max. 3).';
      case DailyBonus.multiplier15:
        return 'Dein Score in dieser Daily-Challenge wird mit 1.5 multipliziert.';
    }
  }
}
