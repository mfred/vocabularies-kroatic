import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/network/dio_client.dart';
import '../core/network/manifest_sync_service.dart';
import '../features/highscore/models/leaderboard_entry.dart';
import '../features/highscore/models/leaderboard_filter.dart';
import '../features/highscore/models/session_detail.dart';
import '../features/highscore/services/leaderboard_service.dart';
import '../features/highscore/services/session_detail_service.dart';
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

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService(ref.watch(databaseProvider));
});

final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, LeaderboardFilter>((ref, filter) async {
  return ref.watch(leaderboardServiceProvider).top(
        range: filter.range,
        lessonId: filter.lessonId,
      );
});

final sessionDetailServiceProvider = Provider<SessionDetailService>((ref) {
  return SessionDetailService(ref.watch(databaseProvider));
});

final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionDetail?, String>((ref, sessionId) async {
  return ref.watch(sessionDetailServiceProvider).load(sessionId);
});
