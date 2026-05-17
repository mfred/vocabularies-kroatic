import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/network/dio_client.dart';
import '../core/network/manifest_sync_service.dart';
import '../features/players/player_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncServiceProvider = Provider<ManifestSyncService>((ref) {
  return ManifestSyncService(buildDio(), ref.watch(databaseProvider));
});

final syncResultProvider = FutureProvider<SyncResult>((ref) async {
  return ref.watch(syncServiceProvider).syncAll();
});

final cachedLessonsProvider = FutureProvider<List<LessonsCacheData>>((ref) async {
  await ref.watch(syncResultProvider.future);
  return ref.watch(databaseProvider).allLessonsByOrder();
});

final lessonItemsProvider =
    FutureProvider.family<List<Item>, String>((ref, lessonId) async {
  return ref.watch(databaseProvider).itemsForLesson(lessonId);
});

final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService(ref.watch(databaseProvider));
});

final currentPlayerProvider = FutureProvider<Player>((ref) async {
  return ref.watch(playerServiceProvider).ensureDefaultPlayer();
});
