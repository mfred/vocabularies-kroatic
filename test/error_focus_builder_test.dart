import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/services/error_focus_builder.dart';
import 'package:vocabularies_kroatic/features/quiz/services/quiz_builder.dart'
    show kQuizQuestionCount;

// Global eindeutige Zähler für Session-/Attempt-IDs über alle Inserts.
int _n = 0;

Future<AppDatabase> _db(List<String> itemIds) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  for (final id in itemIds) {
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            id: id,
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

/// Fügt einen Versuch hinzu. `itemId` darf bewusst auch auf ein nicht
/// existierendes Item zeigen (verbrannte ID).
Future<void> _attempt(
  AppDatabase db, {
  required String itemId,
  required bool wasCorrect,
  String direction = 'de_hr',
}) async {
  final sid = 's${_n++}';
  await db.into(db.quizSessions).insert(
        QuizSessionsCompanion.insert(
          id: sid,
          playerId: 'p1',
          lessonId: 'lesson_0',
          direction: Value(direction),
          startedAt: 0,
        ),
      );
  await db.into(db.quizAttempts).insert(
        QuizAttemptsCompanion.insert(
          id: 'a${_n++}',
          sessionId: sid,
          itemId: itemId,
          questionOrder: 0,
          wasCorrect: wasCorrect,
          responseMs: 1000,
          answeredAt: 0,
        ),
      );
}

void main() {
  test('itemErrorStats: nur Items mit Fehlern, errorRate korrekt & sortiert',
      () async {
    final db = await _db(['a', 'b', 'c', 'd']);
    addTearDown(db.close);

    // a: 2 Fehler          → 2/(2+0+1) = 0.667
    await _attempt(db, itemId: 'a', wasCorrect: false);
    await _attempt(db, itemId: 'a', wasCorrect: false);
    // b: 1 Fehler, 0 ok    → 1/(1+0+1) = 0.5
    await _attempt(db, itemId: 'b', wasCorrect: false);
    // c: 1 Fehler, 5 ok    → 1/(1+5+1) = 0.143
    await _attempt(db, itemId: 'c', wasCorrect: false);
    for (var i = 0; i < 5; i++) {
      await _attempt(db, itemId: 'c', wasCorrect: true);
    }
    // d: nur richtig        → fällt raus (errors == 0)
    await _attempt(db, itemId: 'd', wasCorrect: true);

    final stats = await db.itemErrorStats('p1');
    expect(stats.map((s) => s.itemId).toList(), ['a', 'b', 'c']);
    expect(stats[0].errors, 2);
    expect(stats[0].errorRate, closeTo(0.6667, 0.001));
    expect(stats[2].successes, 5);
    expect(stats[2].errorRate, closeTo(0.1429, 0.001));
  });

  test('hardItems liefert die härtesten zuerst, hardCount zählt sie', () async {
    final db = await _db(['a', 'b', 'c']);
    addTearDown(db.close);
    await _attempt(db, itemId: 'a', wasCorrect: false);
    await _attempt(db, itemId: 'b', wasCorrect: false);
    await _attempt(db, itemId: 'b', wasCorrect: false); // b härter als a
    await _attempt(db, itemId: 'c', wasCorrect: true); // nie falsch → kein Fokus

    final builder = ErrorFocusBuilder(db);
    expect(await builder.hardCount(playerId: 'p1'), 2);
    final items = await builder.hardItems(playerId: 'p1');
    expect(items.map((e) => e.id).toList(), ['b', 'a']);
  });

  test('ohne Fehler ist nichts im Fokus', () async {
    final db = await _db(['a']);
    addTearDown(db.close);
    await _attempt(db, itemId: 'a', wasCorrect: true);
    expect(await ErrorFocusBuilder(db).hardCount(playerId: 'p1'), 0);
    expect(await ErrorFocusBuilder(db).hardItems(playerId: 'p1'), isEmpty);
  });

  test('beide Richtungen zählen in denselben Fehler-Pool', () async {
    final db = await _db(['a', 'b']);
    addTearDown(db.close);
    await _attempt(db, itemId: 'a', wasCorrect: false, direction: 'de_hr');
    await _attempt(db, itemId: 'b', wasCorrect: false, direction: 'hr_de');
    expect(await ErrorFocusBuilder(db).hardCount(playerId: 'p1'), 2);
  });

  test('verbrannte IDs (Item gelöscht) werden ignoriert', () async {
    final db = await _db(['a']);
    addTearDown(db.close);
    await _attempt(db, itemId: 'a', wasCorrect: false);
    await _attempt(db, itemId: 'ghost', wasCorrect: false); // existiert nicht

    final builder = ErrorFocusBuilder(db);
    // itemErrorStats kennt die Roh-IDs (inkl. ghost) …
    expect((await db.itemErrorStats('p1')).length, 2);
    // … hardItems/hardCount filtern auf existierende Items.
    expect(await builder.hardCount(playerId: 'p1'), 1);
    expect(
        (await builder.hardItems(playerId: 'p1')).map((e) => e.id).toList(),
        ['a']);
  });

  test('Session ist auf 10 Fragen begrenzt', () async {
    final ids = [for (var i = 0; i < 12; i++) 'i${i.toString().padLeft(2, '0')}'];
    final db = await _db(ids);
    addTearDown(db.close);
    for (final id in ids) {
      await _attempt(db, itemId: id, wasCorrect: false);
    }
    final items = await ErrorFocusBuilder(db).hardItems(playerId: 'p1');
    expect(items.length, kQuizQuestionCount);
  });

  test('build erzeugt Fragen in Härte-Reihenfolge', () async {
    final db = await _db(['a', 'b', 'c', 'd', 'e']);
    addTearDown(db.close);
    await _attempt(db, itemId: 'a', wasCorrect: false);
    await _attempt(db, itemId: 'a', wasCorrect: false); // härtestes
    await _attempt(db, itemId: 'b', wasCorrect: false);
    await _attempt(db, itemId: 'c', wasCorrect: false);
    await _attempt(db, itemId: 'd', wasCorrect: true);
    await _attempt(db, itemId: 'e', wasCorrect: true);

    final questions = await ErrorFocusBuilder(db)
        .build(playerId: 'p1', direction: QuizDirection.deToHr);
    expect(questions.map((q) => q.itemId).toList(), ['a', 'b', 'c']);
    // Prompt = DE-Seite in deToHr.
    expect(questions.first.prompt, 'de_a');
  });
}
