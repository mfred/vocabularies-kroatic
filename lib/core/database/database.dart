import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/quiz/models/item_attempt_stats.dart';

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

  @override
  Set<Column> get primaryKey => {id};
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

@DriftDatabase(tables: [Items, LessonsCache, Players, QuizSessions, QuizAttempts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(players);
            await m.createTable(quizSessions);
            await m.createTable(quizAttempts);
          }
          if (from < 3) {
            await m.addColumn(quizSessions, quizSessions.direction);
            // Backfill direction aus dem alten mode-Suffix.
            await customStatement(
              "UPDATE quiz_sessions SET direction = "
              "CASE WHEN mode LIKE '%_hr_de' THEN 'hr_de' "
              "ELSE 'de_hr' END",
            );
          }
          if (from < 4) {
            await m.addColumn(quizAttempts, quizAttempts.jokersJson);
          }
        },
      );

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

  Future<int> countItemsByLesson(String lessonId) async {
    final row = await (selectOnly(items)
          ..addColumns([items.id.count()])
          ..where(items.lessonId.equals(lessonId)))
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

  Future<Map<String, ItemAttemptStats>> attemptStatsByItem({
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
    final out = <String, ItemAttemptStats>{};
    for (final r in rows) {
      final a = r.readTable(quizAttempts);
      final s = out[a.itemId] ?? ItemAttemptStats.empty();
      out[a.itemId] = s.applyAttempt(
        wasCorrect: a.wasCorrect,
        atMs: a.answeredAt,
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

  Future<List<QuizSession>> topSessions({
    required int sinceMs,
    required int untilMs,
    String? lessonId,
    int limit = 50,
  }) {
    final q = select(quizSessions)
      ..where((t) =>
          t.finishedAt.isNotNull() &
          t.finishedAt.isBetweenValues(sinceMs, untilMs))
      ..orderBy([
        (t) => OrderingTerm(
            expression: t.scorePoints, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.durationMs),
      ])
      ..limit(limit);
    if (lessonId != null) {
      q.where((t) => t.lessonId.equals(lessonId));
    }
    return q.get();
  }

  Future<List<DetailedSessionRow>> topSessionsDetailed({
    required int sinceMs,
    required int untilMs,
    String? lessonId,
    int limit = 50,
  }) async {
    final q = select(quizSessions).join([
      leftOuterJoin(players, players.id.equalsExp(quizSessions.playerId)),
      leftOuterJoin(
        lessonsCache,
        lessonsCache.lessonId.equalsExp(quizSessions.lessonId),
      ),
    ])
      ..where(quizSessions.finishedAt.isNotNull() &
          quizSessions.finishedAt.isBetweenValues(sinceMs, untilMs))
      ..orderBy([
        OrderingTerm(
            expression: quizSessions.scorePoints,
            mode: OrderingMode.desc),
        OrderingTerm(expression: quizSessions.durationMs),
      ])
      ..limit(limit);
    if (lessonId != null) {
      q.where(quizSessions.lessonId.equals(lessonId));
    }
    final rows = await q.get();
    return rows
        .map((r) => DetailedSessionRow(
              session: r.readTable(quizSessions),
              player: r.readTableOrNull(players),
              lesson: r.readTableOrNull(lessonsCache),
            ))
        .toList();
  }
}

class DetailedSessionRow {
  const DetailedSessionRow({
    required this.session,
    required this.player,
    required this.lesson,
  });

  final QuizSession session;
  final Player? player;
  final LessonsCacheData? lesson;
}

class DetailedAttemptRow {
  const DetailedAttemptRow({required this.attempt, required this.item});

  final QuizAttempt attempt;
  final Item? item;
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'vocabularies_kroatic');
}
