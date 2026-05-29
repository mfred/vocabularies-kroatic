import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/streaks/services/streak_service.dart';

int _ms(int y, int m, int d, [int h = 12]) =>
    DateTime(y, m, d, h).millisecondsSinceEpoch;

Future<AppDatabase> _db() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
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

Future<void> _finishedOn(AppDatabase db, int y, int m, int d) async {
  final ts = _ms(y, m, d);
  await db.into(db.quizSessions).insert(
        QuizSessionsCompanion.insert(
          id: 's_${y}_${m}_$d',
          playerId: 'p1',
          lessonId: 'lesson_0',
          startedAt: ts,
          finishedAt: Value(ts),
        ),
      );
}

void main() {
  // Fixe Uhr: „heute" = 18.05.2026.
  final now = DateTime(2026, 5, 18, 10);

  test('currentStreak ist rein lesend — verbraucht keine Schoner', () async {
    final db = await _db();
    // gestern (17.) + heute (18.) leer, vorher gespielt → Saver überbrückt
    // die Lücke. currentStreak darf dabei NICHTS persistieren.
    await _finishedOn(db, 2026, 5, 16);
    await _finishedOn(db, 2026, 5, 15);
    await db.incrementStreakSavers('p1', cap: kMaxStreakSavers);
    final svc = StreakService(db, clock: () => now);

    final before = await db.getStreakSavers('p1');
    final s1 = await svc.currentStreak('p1');
    final s2 = await svc.currentStreak('p1');
    final after = await db.getStreakSavers('p1');

    expect(s1, s2, reason: 'zwei aufeinanderfolgende Reads sind konsistent');
    expect(after, before, reason: 'Lesen verbraucht keinen Schoner');

    await db.close();
  });

  test('settleStreakSavers ist pro Tag idempotent (zweiter Aufruf = no-op)',
      () async {
    final db = await _db();
    await _finishedOn(db, 2026, 5, 18); // heute gespielt
    await _finishedOn(db, 2026, 5, 16); // 17. = Lücke
    await _finishedOn(db, 2026, 5, 15);
    // 3 Schoner, damit nach dem ersten Settle noch Reservoir übrig ist und der
    // Tagesschlüssel-Guard (nicht der savers==0-Pfad) das zweite Settle stoppt.
    for (var i = 0; i < 3; i++) {
      await db.incrementStreakSavers('p1', cap: kMaxStreakSavers);
    }
    final svc = StreakService(db, clock: () => now);
    expect(await db.getStreakSavers('p1'), 3);

    await svc.settleStreakSavers('p1');
    final afterFirst = await db.getStreakSavers('p1');
    expect(afterFirst, lessThan(3),
        reason: 'mind. ein Schoner für die Lücke am 17. verbraucht');

    await svc.settleStreakSavers('p1');
    expect(await db.getStreakSavers('p1'), afterFirst,
        reason: 'zweiter Aufruf am selben Tag zieht nichts mehr ab');

    await db.close();
  });

  test('settleStreakSavers ohne Reservoir ist ein No-op', () async {
    final db = await _db();
    await _finishedOn(db, 2026, 5, 18);
    await _finishedOn(db, 2026, 5, 16); // Lücke, aber kein Schoner vorhanden
    final svc = StreakService(db, clock: () => now);

    await svc.settleStreakSavers('p1');
    expect(await db.getStreakSavers('p1'), 0);

    await db.close();
  });
}
