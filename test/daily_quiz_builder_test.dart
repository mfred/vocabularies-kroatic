import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/services/daily_quiz_builder.dart';

Future<AppDatabase> _seededDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  // 30 Test-Items über 3 Lektionen — genug für 10 Fragen + Distractoren.
  for (int i = 0; i < 30; i++) {
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: 'item_$i',
            lessonId: 'lesson_${i ~/ 10}',
            type: 'word',
            stage: 'words',
            difficulty: 1,
            deText: 'de_$i',
            hrText: 'hr_$i',
            lessonVersion: '1.0.0',
          ),
        );
  }
  return db;
}

void main() {
  test('DailyQuizBuilder ist deterministisch pro Datum', () async {
    final db = await _seededDb();
    addTearDown(db.close);
    final date = DateTime(2026, 5, 27);
    final a = await DailyQuizBuilder(db).build(
      date: date,
      direction: QuizDirection.deToHr,
    );
    final b = await DailyQuizBuilder(db).build(
      date: date,
      direction: QuizDirection.deToHr,
    );
    expect(a.length, 10);
    expect(b.length, 10);
    expect(
      a.map((q) => q.itemId).toList(),
      b.map((q) => q.itemId).toList(),
    );
    expect(a.first.options, b.first.options);
  });

  test('DailyQuizBuilder unterscheidet sich zwischen zwei Tagen', () async {
    final db = await _seededDb();
    addTearDown(db.close);
    final a = await DailyQuizBuilder(db).build(
      date: DateTime(2026, 5, 27),
      direction: QuizDirection.deToHr,
    );
    final b = await DailyQuizBuilder(db).build(
      date: DateTime(2026, 5, 28),
      direction: QuizDirection.deToHr,
    );
    // Mindestens ein Item-Picking sollte sich unterscheiden.
    expect(
      a.map((q) => q.itemId).toList(),
      isNot(equals(b.map((q) => q.itemId).toList())),
    );
  });

  test('dailyDateKey kodiert YYYYMMDD', () {
    expect(dailyDateKey(DateTime(2026, 5, 27)), 20260527);
    expect(dailyDateKey(DateTime(2025, 12, 31)), 20251231);
  });
}
