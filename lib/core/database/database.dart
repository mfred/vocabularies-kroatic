import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(tables: [Items, LessonsCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'vocabularies_kroatic');
}
