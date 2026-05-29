import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/quiz/services/sm2_scheduler.dart';

part 'database.g.dart';

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text()();
  TextColumn get type => text()();
  TextColumn get stage => text()();
  IntColumn get difficulty => integer()();
  TextColumn get deText => text()();
  TextColumn get deIpa => text().nullable()();
  TextColumn get dePos => text().nullable()();
  TextColumn get hrText => text()();
  TextColumn get hrIpa => text().nullable()();
  TextColumn get hrPos => text().nullable()();
  TextColumn get alternativesHrJson => text().nullable()();
  TextColumn get tagsJson => text().nullable()();
  TextColumn get notesDe => text().nullable()();
  TextColumn get requiresJson => text().nullable()();
  TextColumn get licenseJson => text().nullable()();
  TextColumn get lessonVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LessonsCache extends Table {
  TextColumn get lessonId => text()();
  TextColumn get version => text()();
  IntColumn get downloadedAt => integer()();
  TextColumn get sha256 => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get titleDe => text()();
  TextColumn get titleHr => text()();
  TextColumn get descriptionDe => text().nullable()();
  IntColumn get difficulty => integer()();
  IntColumn get wordCount => integer()();
  IntColumn get phraseCount => integer()();
  IntColumn get sentenceCount => integer()();
  TextColumn get prerequisitesJson => text().nullable()();
  TextColumn get tagsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {lessonId};
}

class Players extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  IntColumn get createdAt => integer()();
  BoolColumn get isLocal => boolean().withDefault(const Constant(true))();
  TextColumn get remoteUserId => text().nullable()();
  IntColumn get pendingBonusPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get streakSavers =>
      integer().withDefault(const Constant(0))();
  IntColumn get doublePointsRemaining =>
      integer().withDefault(const Constant(0))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Tagesschlüssel (yyyymmdd) des letzten Streak-Schoner-Verbrauchs.
  /// Verhindert, dass mehrere Sessions am selben Tag denselben Schoner doppelt
  /// abziehen (Idempotenz von [StreakService.settleStreakSavers]).
  IntColumn get lastSaverConsumedDayKey => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class StreakRewards extends Table {
  TextColumn get playerId => text().references(Players, #id)();
  IntColumn get streakDay => integer()();
  IntColumn get claimedAt => integer()();
  IntColumn get bonusPoints => integer()();

  @override
  Set<Column> get primaryKey => {playerId, streakDay};
}

class QuizSessions extends Table {
  TextColumn get id => text()();
  TextColumn get playerId => text().references(Players, #id)();
  TextColumn get lessonId => text()();
  TextColumn get mode => text().withDefault(const Constant('mc_de_hr'))();
  TextColumn get direction => text().withDefault(const Constant('de_hr'))();
  IntColumn get startedAt => integer()();
  IntColumn get finishedAt => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get hintsUsed => integer().withDefault(const Constant(0))();
  IntColumn get scorePoints => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class QuizAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(QuizSessions, #id)();
  TextColumn get itemId => text()();
  IntColumn get questionOrder => integer()();
  BoolColumn get wasCorrect => boolean()();
  BoolColumn get hintUsed => boolean().withDefault(const Constant(false))();
  IntColumn get responseMs => integer()();
  TextColumn get pickedOption => text().nullable()();
  TextColumn get jokersJson => text().nullable()();
  IntColumn get answeredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyChallenges extends Table {
  IntColumn get dateKey => integer()();
  TextColumn get playerId => text().references(Players, #id)();
  TextColumn get sessionId => text()();
  IntColumn get completedAt => integer()();
  IntColumn get scorePoints => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {dateKey, playerId};
}

@DriftDatabase(tables: [
  Items,
  LessonsCache,
  Players,
  QuizSessions,
  QuizAttempts,
  StreakRewards,
  DailyChallenges,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createPerformanceIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(players);
            await m.createTable(quizSessions);
            await m.createTable(quizAttempts);
          }
          if (from < 3) {
            await m.addColumn(quizSessions, quizSessions.direction);
            await customStatement(
              "UPDATE quiz_sessions SET direction = "
              "CASE WHEN mode LIKE '%_hr_de' THEN 'hr_de' "
              "ELSE 'de_hr' END",
            );
          }
          if (from < 4) {
            await m.addColumn(quizAttempts, quizAttempts.jokersJson);
          }
          if (from < 5) {
            await m.addColumn(players, players.pendingBonusPoints);
            await m.createTable(streakRewards);
          }
          if (from < 6) {
            await m.addColumn(players, players.streakSavers);
            await m.addColumn(players, players.doublePointsRemaining);
            // Skala x20 ab Iteration 21 — alte Scores wären in der neuen
            // Skala künstlich überhöht. In der Entwicklungsphase wird der
            // bestehende Highscore-Stand explizit genullt.
            await customStatement(
              'UPDATE quiz_sessions SET score_points = 0',
            );
            await customStatement(
              'UPDATE players SET pending_bonus_points = 0',
            );
            await customStatement('DELETE FROM streak_rewards');
          }
          if (from < 7) {
            await m.createTable(dailyChallenges);
          }
          if (from < 8) {
            await m.addColumn(players, players.reminderEnabled);
          }
          if (from < 9) {
            await m.addColumn(players, players.lastSaverConsumedDayKey);
          }
          if (from < 10) {
            await _createPerformanceIndexes();
          }
        },
      );

  /// Sekundär-Indizes auf den heißen Join-/Filter-Spalten der Quiz-Queries
  /// (watchLessonProgress, wrongItemsForLesson, seenItemIdsForPlayer,
  /// sm2StatesByItem). `IF NOT EXISTS` macht den Aufruf idempotent, sodass
  /// onCreate (Fresh-Install) und onUpgrade dieselbe Methode nutzen können.
  Future<void> _createPerformanceIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_attempts_session '
        'ON quiz_attempts (session_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_sessions_player_dir '
        'ON quiz_sessions (player_id, direction)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_items_lesson '
        'ON items (lesson_id)');
  }

  Future<List<LessonsCacheData>> allLessonsByOrder() {
    return (select(lessonsCache)
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .get();
  }

  Future<int> countItems() async {
    final row = await (selectOnly(items)..addColumns([items.id.count()]))
        .getSingle();
    return row.read(items.id.count()) ?? 0;
  }

  Future<LessonsCacheData?> getLessonCache(String lessonId) {
    return (select(lessonsCache)..where((t) => t.lessonId.equals(lessonId)))
        .getSingleOrNull();
  }

  Future<void> upsertLessonCache(LessonsCacheCompanion entry) {
    return into(lessonsCache).insertOnConflictUpdate(entry);
  }

  Future<void> replaceLessonItems(
    String lessonId,
    List<ItemsCompanion> newItems,
  ) async {
    await transaction(() async {
      await (delete(items)..where((t) => t.lessonId.equals(lessonId))).go();
      await batch((b) => b.insertAll(items, newItems));
    });
  }

  Future<List<Item>> itemsForLesson(String lessonId) {
    return (select(items)
          ..where((t) => t.lessonId.equals(lessonId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();
  }

  Future<List<Item>> allItems() {
    return (select(items)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
  }

  /// Anteil [0.0, 1.0] der Items pro Lektion, die der Spieler mindestens
  /// einmal richtig beantwortet hat. Lektionen ohne Items fehlen in der Map.
  /// Direction-unabhängig — beide Richtungen zählen in denselben Pool.
  Stream<Map<String, double>> watchLessonProgress(String playerId) {
    final query = customSelect(
      '''
SELECT items.lesson_id AS lesson_id,
       COUNT(DISTINCT items.id) AS total,
       COUNT(DISTINCT CASE WHEN correct_attempts.item_id IS NOT NULL
                           THEN items.id END) AS correct
FROM items
LEFT JOIN (
  SELECT DISTINCT qa.item_id
  FROM quiz_attempts qa
  INNER JOIN quiz_sessions qs ON qs.id = qa.session_id
  WHERE qs.player_id = ?1 AND qa.was_correct = 1
) AS correct_attempts ON correct_attempts.item_id = items.id
GROUP BY items.lesson_id
''',
      variables: [Variable.withString(playerId)],
      readsFrom: {items, quizAttempts, quizSessions},
    );
    return query.watch().map((rows) {
      final out = <String, double>{};
      for (final r in rows) {
        final lessonId = r.read<String>('lesson_id');
        final total = r.read<int>('total');
        final correct = r.read<int>('correct');
        out[lessonId] = total == 0 ? 0.0 : correct / total;
      }
      return out;
    });
  }

  Future<DailyChallenge?> getDailyChallenge({
    required int dateKey,
    required String playerId,
  }) {
    return (select(dailyChallenges)
          ..where(
              (t) => t.dateKey.equals(dateKey) & t.playerId.equals(playerId)))
        .getSingleOrNull();
  }

  Future<void> insertDailyChallenge(DailyChallengesCompanion entry) {
    return into(dailyChallenges).insert(entry);
  }

  Future<bool> getReminderEnabled(String playerId) async {
    final row = await (select(players)..where((t) => t.id.equals(playerId)))
        .getSingleOrNull();
    return row?.reminderEnabled ?? true;
  }

  Future<void> setReminderEnabled(String playerId, bool enabled) async {
    await (update(players)..where((t) => t.id.equals(playerId)))
        .write(PlayersCompanion(reminderEnabled: Value(enabled)));
  }

  Future<Player?> getAnyLocalPlayer() {
    return (select(players)
          ..where((t) => t.isLocal.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> insertPlayer(PlayersCompanion entry) {
    return into(players).insert(entry);
  }

  Future<void> insertQuizSession(QuizSessionsCompanion entry) {
    return into(quizSessions).insert(entry);
  }

  Future<void> finalizeQuizSession({
    required String sessionId,
    required int finishedAt,
    required int durationMs,
    required int correctCount,
    required int totalCount,
    required int hintsUsed,
    required int scorePoints,
  }) {
    return (update(quizSessions)..where((t) => t.id.equals(sessionId))).write(
      QuizSessionsCompanion(
        finishedAt: Value(finishedAt),
        durationMs: Value(durationMs),
        correctCount: Value(correctCount),
        totalCount: Value(totalCount),
        hintsUsed: Value(hintsUsed),
        scorePoints: Value(scorePoints),
      ),
    );
  }

  Future<QuizSession?> getQuizSession(String sessionId) {
    return (select(quizSessions)..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
  }

  Future<void> insertQuizAttempt(QuizAttemptsCompanion entry) {
    return into(quizAttempts).insert(entry);
  }

  /// Liefert alle Items der Lektion, bei denen der letzte Versuch des
  /// Spielers `wasCorrect == false` war. Items, die der Spieler nie
  /// angefasst hat, fallen ebenso raus wie zuletzt richtig beantwortete.
  ///
  /// Direction-agnostisch — beide Richtungen zählen in denselben Pool.
  Future<List<Item>> wrongItemsForLesson({
    required String playerId,
    required String lessonId,
  }) async {
    final query = select(quizAttempts).join([
      innerJoin(
        quizSessions,
        quizSessions.id.equalsExp(quizAttempts.sessionId),
      ),
      innerJoin(items, items.id.equalsExp(quizAttempts.itemId)),
    ])
      ..where(quizSessions.playerId.equals(playerId) &
          items.lessonId.equals(lessonId))
      ..orderBy([OrderingTerm.desc(quizAttempts.answeredAt)]);
    final rows = await query.get();
    final seen = <String>{};
    final out = <Item>[];
    for (final r in rows) {
      final a = r.readTable(quizAttempts);
      if (!seen.add(a.itemId)) continue; // nur der erste = neueste Treffer
      if (!a.wasCorrect) out.add(r.readTable(items));
    }
    return out;
  }

  /// Kumulierte Fehl-/Treffer-Zähler pro Item über ALLE Lektionen und beide
  /// Übersetzungsrichtungen — Grundlage des „Fehlerfokus"-Modus. Nur Items mit
  /// mindestens einem Fehlversuch erscheinen; absteigend nach
  /// errorRate = errors / (errors + successes + 1) sortiert (bei Gleichstand:
  /// mehr Fehler zuerst, dann stabil nach Item-ID).
  ///
  /// Direction-agnostisch — wie [wrongItemsForLesson]/[watchLessonProgress]
  /// zählen beide Richtungen in denselben Pool.
  Future<List<ItemErrorStat>> itemErrorStats(String playerId) async {
    final query = customSelect(
      '''
SELECT qa.item_id AS item_id,
       SUM(CASE WHEN qa.was_correct = 0 THEN 1 ELSE 0 END) AS errors,
       SUM(CASE WHEN qa.was_correct = 1 THEN 1 ELSE 0 END) AS successes
FROM quiz_attempts qa
INNER JOIN quiz_sessions qs ON qs.id = qa.session_id
WHERE qs.player_id = ?1
GROUP BY qa.item_id
HAVING errors > 0
''',
      variables: [Variable.withString(playerId)],
      readsFrom: {quizAttempts, quizSessions},
    );
    final rows = await query.get();
    final stats = rows
        .map((r) => ItemErrorStat(
              itemId: r.read<String>('item_id'),
              errors: r.read<int>('errors'),
              successes: r.read<int>('successes'),
            ))
        .toList()
      ..sort((a, b) {
        final byRate = b.errorRate.compareTo(a.errorRate);
        if (byRate != 0) return byRate;
        final byErrors = b.errors.compareTo(a.errors);
        if (byErrors != 0) return byErrors;
        return a.itemId.compareTo(b.itemId);
      });
    return stats;
  }

  Future<Set<String>> seenItemIdsForPlayer({
    required String playerId,
    required String mode,
  }) async {
    final query = select(quizAttempts).join([
      innerJoin(
        quizSessions,
        quizSessions.id.equalsExp(quizAttempts.sessionId),
      ),
    ])
      ..where(quizSessions.playerId.equals(playerId) &
          quizSessions.direction.equals(mode));
    final rows = await query.get();
    return rows
        .map((r) => r.readTable(quizAttempts).itemId)
        .toSet();
  }

  /// Faltet die Antwort-Historie pro Item durch die SM-2-Rekurrenz und liefert
  /// den aktuellen Spaced-Repetition-Zustand. Nur Items mit mindestens einem
  /// Versuch erscheinen. Richtungs-spezifisch (`mode` = `de_hr`/`hr_de`), da
  /// die beiden Übersetzungsrichtungen getrennt erlernt werden.
  Future<Map<String, Sm2State>> sm2StatesByItem({
    required String playerId,
    required String mode,
  }) async {
    final query = select(quizAttempts).join([
      innerJoin(
        quizSessions,
        quizSessions.id.equalsExp(quizAttempts.sessionId),
      ),
    ])
      ..where(quizSessions.playerId.equals(playerId) &
          quizSessions.direction.equals(mode))
      ..orderBy([OrderingTerm.asc(quizAttempts.answeredAt)]);
    final rows = await query.get();
    const scheduler = Sm2Scheduler();
    final out = <String, Sm2State>{};
    for (final r in rows) {
      final a = r.readTable(quizAttempts);
      final prev = out[a.itemId] ?? Sm2State.initial();
      out[a.itemId] = scheduler.applyQuality(
        prev,
        quality: qualityFromAttempt(
          wasCorrect: a.wasCorrect,
          hintUsed: a.hintUsed,
        ),
        reviewedAtMs: a.answeredAt,
      );
    }
    return out;
  }

  Future<List<DetailedAttemptRow>> attemptsWithItemForSession(
    String sessionId,
  ) async {
    final query = select(quizAttempts).join([
      leftOuterJoin(items, items.id.equalsExp(quizAttempts.itemId)),
    ])
      ..where(quizAttempts.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(quizAttempts.questionOrder)]);
    final rows = await query.get();
    return rows
        .map((r) => DetailedAttemptRow(
              attempt: r.readTable(quizAttempts),
              item: r.readTableOrNull(items),
            ))
        .toList();
  }

  /// Anzahl der Sessions des Spielers, die *gestartet* aber nie
  /// finalisiert wurden (App-Crash, Quiz abgebrochen, …). Reine
  /// Diagnose-Info — hilft beim Debugging, wenn der Streak nicht
  /// hochzählt.
  Future<int> unfinishedSessionsCountForPlayer(String playerId) async {
    final row = await (selectOnly(quizSessions)
          ..addColumns([quizSessions.id.count()])
          ..where(quizSessions.playerId.equals(playerId) &
              quizSessions.finishedAt.isNull()))
        .getSingle();
    return row.read(quizSessions.id.count()) ?? 0;
  }

  Future<List<int>> finishedAtsForPlayer(String playerId) async {
    final q = selectOnly(quizSessions)
      ..addColumns([quizSessions.finishedAt])
      ..where(quizSessions.playerId.equals(playerId) &
          quizSessions.finishedAt.isNotNull())
      ..orderBy([
        OrderingTerm(
            expression: quizSessions.finishedAt,
            mode: OrderingMode.desc),
      ]);
    final rows = await q.get();
    return rows
        .map((r) => r.read(quizSessions.finishedAt))
        .whereType<int>()
        .toList();
  }

  Future<bool> hasClaimedStreakReward(String playerId, int streakDay) async {
    final row = await (select(streakRewards)
          ..where((t) =>
              t.playerId.equals(playerId) & t.streakDay.equals(streakDay)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> insertStreakReward(StreakRewardsCompanion entry) {
    return into(streakRewards).insert(entry);
  }

  Future<int> getPendingBonusPoints(String playerId) async {
    final row = await (select(players)..where((t) => t.id.equals(playerId)))
        .getSingleOrNull();
    return row?.pendingBonusPoints ?? 0;
  }

  Future<void> addPendingBonusPoints(String playerId, int points) async {
    await customStatement(
      'UPDATE players SET pending_bonus_points = pending_bonus_points + ? '
      'WHERE id = ?',
      [points, playerId],
    );
  }

  Future<void> clearPendingBonusPoints(String playerId) async {
    await (update(players)..where((t) => t.id.equals(playerId)))
        .write(const PlayersCompanion(pendingBonusPoints: Value(0)));
  }

  Future<int> getStreakSavers(String playerId) async {
    final row = await (select(players)..where((t) => t.id.equals(playerId)))
        .getSingleOrNull();
    return row?.streakSavers ?? 0;
  }

  /// Inkrementiert um 1, aber mit Cap. Liefert den neuen Stand zurück.
  Future<int> incrementStreakSavers(String playerId, {required int cap}) async {
    await customStatement(
      'UPDATE players SET streak_savers = MIN(streak_savers + 1, ?) '
      'WHERE id = ?',
      [cap, playerId],
    );
    return getStreakSavers(playerId);
  }

  /// Zieht `count` Saver ab (bis runter auf 0).
  Future<void> consumeStreakSavers(String playerId, int count) async {
    if (count <= 0) return;
    await customStatement(
      'UPDATE players SET streak_savers = MAX(streak_savers - ?, 0) '
      'WHERE id = ?',
      [count, playerId],
    );
  }

  /// Tagesschlüssel (yyyymmdd) des letzten Saver-Verbrauchs, oder null.
  Future<int?> getLastSaverConsumedDayKey(String playerId) async {
    final row = await (select(players)..where((t) => t.id.equals(playerId)))
        .getSingleOrNull();
    return row?.lastSaverConsumedDayKey;
  }

  Future<void> setLastSaverConsumedDayKey(String playerId, int dayKey) async {
    await (update(players)..where((t) => t.id.equals(playerId)))
        .write(PlayersCompanion(lastSaverConsumedDayKey: Value(dayKey)));
  }

  Future<int> getDoublePointsRemaining(String playerId) async {
    final row = await (select(players)..where((t) => t.id.equals(playerId)))
        .getSingleOrNull();
    return row?.doublePointsRemaining ?? 0;
  }

  /// Setzt das Feld auf 1 (überschreibt, statt aufzustapeln).
  Future<void> grantDoublePoints(String playerId) async {
    await (update(players)..where((t) => t.id.equals(playerId)))
        .write(const PlayersCompanion(doublePointsRemaining: Value(1)));
  }

  /// Konsumiert einen Doppel-Punkte-Boost, falls verfügbar. Liefert true,
  /// wenn tatsächlich verbraucht wurde.
  Future<bool> consumeDoublePoints(String playerId) async {
    final current = await getDoublePointsRemaining(playerId);
    if (current <= 0) return false;
    await customStatement(
      'UPDATE players SET double_points_remaining = double_points_remaining - 1 '
      'WHERE id = ? AND double_points_remaining > 0',
      [playerId],
    );
    return true;
  }

}

class DetailedAttemptRow {
  const DetailedAttemptRow({required this.attempt, required this.item});

  final QuizAttempt attempt;
  final Item? item;
}

/// Kumulierte Antwort-Statistik eines Items für den Fehlerfokus
/// (siehe [AppDatabase.itemErrorStats]).
class ItemErrorStat {
  const ItemErrorStat({
    required this.itemId,
    required this.errors,
    required this.successes,
  });

  final String itemId;
  final int errors;
  final int successes;

  /// errorRate nach PROJECT.md §2.4: `errors / (errors + successes + 1)`.
  /// Das +1 dämpft Items mit wenig Daten und vermeidet Division durch 0.
  double get errorRate => errors / (errors + successes + 1);
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'vocabularies_kroatic');
}
