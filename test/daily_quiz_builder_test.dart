import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/services/daily_assignment.dart';
import 'package:vocabularies_kroatic/features/quiz/services/daily_quiz_builder.dart';

Future<AppDatabase> _seededDb({int itemCount = 40, int lessonItems = 20}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // Lektionen-Cache, damit category-Modus eine Auswahl hat (>= 12 Items).
  for (int l = 0; l < itemCount ~/ lessonItems; l++) {
    await db.into(db.lessonsCache).insert(
          LessonsCacheCompanion.insert(
            lessonId: 'lesson_$l',
            version: '1.0.0',
            downloadedAt: 0,
            sha256: 'abc',
            orderIndex: l,
            titleDe: 'Lektion $l',
            titleHr: 'Lekcija $l',
            difficulty: 1,
            wordCount: lessonItems,
            phraseCount: 0,
            sentenceCount: 0,
          ),
        );
  }
  for (int i = 0; i < itemCount; i++) {
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: 'item_$i',
            lessonId: 'lesson_${i ~/ lessonItems}',
            type: 'word',
            stage: 'words',
            difficulty: 1,
            deText: 'de_$i',
            hrText: 'hr_$i',
            lessonVersion: '1.0.0',
          ),
        );
  }
  await db.into(db.players).insert(
        PlayersCompanion.insert(
          id: 'p1',
          displayName: 'Test',
          createdAt: 0,
          isLocal: const Value(true),
        ),
      );
  return db;
}

void main() {
  test('DailyAssigner ist deterministisch pro (Datum, Spieler)', () async {
    final db = await _seededDb();
    addTearDown(db.close);
    final assigner = DailyAssigner(db);
    final a = await assigner.assignFor(
        date: DateTime(2026, 5, 27), playerId: 'p1');
    final b = await assigner.assignFor(
        date: DateTime(2026, 5, 27), playerId: 'p1');
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(a!.mode, b!.mode);
    expect(a.bonus, b.bonus);
  });

  test('DailyAssigner unterscheidet sich zwischen zwei Spielern (meistens)',
      () async {
    final db = await _seededDb();
    addTearDown(db.close);
    await db.into(db.players).insert(
          PlayersCompanion.insert(
            id: 'p2',
            displayName: 'Test 2',
            createdAt: 0,
            isLocal: const Value(true),
          ),
        );
    final assigner = DailyAssigner(db);
    // Über mehrere Tage muss mindestens einmal ein anderer Mode oder Bonus
    // rauskommen — sonst wäre der Seed nicht player-abhängig.
    bool anyDifference = false;
    for (int day = 1; day <= 30; day++) {
      final a1 = await assigner.assignFor(
          date: DateTime(2026, 1, day), playerId: 'p1');
      final a2 = await assigner.assignFor(
          date: DateTime(2026, 1, day), playerId: 'p2');
      if (a1?.mode != a2?.mode || a1?.bonus != a2?.bonus) {
        anyDifference = true;
        break;
      }
    }
    expect(anyDifference, isTrue);
  });

  test('DailyQuizBuilder erzeugt 5 Fragen für newWords-Pool', () async {
    final db = await _seededDb();
    addTearDown(db.close);
    final pool = (await db.allItems()).take(5).toList();
    final assignment = DailyAssignment(
      mode: DailyMode.newWords,
      bonus: DailyBonus.flat30,
      itemPool: pool,
    );
    final questions = await DailyQuizBuilder(db).build(
      date: DateTime(2026, 5, 27),
      direction: QuizDirection.deToHr,
      playerId: 'p1',
      assignment: assignment,
    );
    expect(questions.length, 5);
    for (final q in questions) {
      expect(q.options.length, 4);
      expect(q.options.contains(q.correct), isTrue);
    }
  });

  test('dailyDateKey kodiert YYYYMMDD', () {
    expect(dailyDateKey(DateTime(2026, 5, 27)), 20260527);
    expect(dailyDateKey(DateTime(2025, 12, 31)), 20251231);
  });
}
