import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/services/due_review_builder.dart';

const int _day = 86400000;

Future<AppDatabase> _db() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  for (final id in ['a', 'b', 'c']) {
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: 'item_$id',
            lessonId: 'lesson_0',
            type: 'word',
            stage: 'words',
            difficulty: 1,
            deText: 'de_$id',
            hrText: 'hr_$id',
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

Future<void> _attempt(
  AppDatabase db, {
  required String sessionId,
  required String itemId,
  required bool wasCorrect,
  required int answeredAt,
}) async {
  await db.into(db.quizSessions).insert(
        QuizSessionsCompanion.insert(
          id: sessionId,
          playerId: 'p1',
          lessonId: 'lesson_0',
          direction: const Value('de_hr'),
          startedAt: answeredAt,
        ),
      );
  await db.into(db.quizAttempts).insert(
        QuizAttemptsCompanion.insert(
          id: 'att_$itemId',
          sessionId: sessionId,
          itemId: itemId,
          questionOrder: 0,
          wasCorrect: wasCorrect,
          responseMs: 1000,
          answeredAt: answeredAt,
        ),
      );
}

void main() {
  test('dueItems liefert nur überfällige Items, überfälligste zuerst',
      () async {
    final db = await _db();
    addTearDown(db.close);
    const now = 100 * _day;

    // a: vor 5 Tagen richtig → fällig seit 4 Tagen.
    await _attempt(db,
        sessionId: 's_a',
        itemId: 'item_a',
        wasCorrect: true,
        answeredAt: now - 5 * _day);
    // b: vor 10 Tagen richtig → noch länger überfällig.
    await _attempt(db,
        sessionId: 's_b',
        itemId: 'item_b',
        wasCorrect: true,
        answeredAt: now - 10 * _day);
    // c: gerade eben richtig → erst morgen fällig.
    await _attempt(db,
        sessionId: 's_c',
        itemId: 'item_c',
        wasCorrect: true,
        answeredAt: now);

    final builder = DueReviewBuilder(db);

    final count = await builder.dueCount(
        playerId: 'p1', direction: QuizDirection.deToHr, asOfMs: now);
    expect(count, 2);

    final due = await builder.dueItems(
        playerId: 'p1', direction: QuizDirection.deToHr, asOfMs: now);
    expect(due.map((e) => e.id).toList(), ['item_b', 'item_a']);
  });

  test('nie beantwortete Items sind nicht fällig', () async {
    final db = await _db();
    addTearDown(db.close);
    final count = await DueReviewBuilder(db).dueCount(
        playerId: 'p1', direction: QuizDirection.deToHr, asOfMs: 100 * _day);
    expect(count, 0);
  });

  test('andere Richtung teilt sich den Fällig-Pool nicht', () async {
    final db = await _db();
    addTearDown(db.close);
    const now = 100 * _day;
    await _attempt(db,
        sessionId: 's_a',
        itemId: 'item_a',
        wasCorrect: true,
        answeredAt: now - 5 * _day);
    // In HR→DE wurde nichts beantwortet → nichts fällig.
    final count = await DueReviewBuilder(db).dueCount(
        playerId: 'p1', direction: QuizDirection.hrToDe, asOfMs: now);
    expect(count, 0);
  });
}
