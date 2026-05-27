import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart' hide StreakReward;
import '../features/auth/services/auth_service.dart';
import '../features/auth/services/player_stats_service.dart';
import '../core/network/dio_client.dart';
import '../core/network/manifest_sync_service.dart';
import '../core/services/stt_service.dart';
import '../core/services/tts_service.dart';
import '../features/highscore/models/leaderboard_entry.dart';
import '../features/highscore/models/leaderboard_filter.dart';
import '../features/highscore/models/session_detail.dart';
import '../features/highscore/services/remote_leaderboard_service.dart';
import '../features/highscore/services/session_detail_service.dart';
import '../features/players/player_service.dart';
import '../features/quiz/models/quiz_direction.dart';
import '../features/quiz/services/daily_assignment.dart';
import '../features/quiz/services/daily_quiz_builder.dart';
import '../features/streaks/models/streak_reward.dart';
import '../features/streaks/services/reminder_service.dart';
import '../features/streaks/services/streak_service.dart';

class PreferredDirection extends Notifier<QuizDirection> {
  @override
  QuizDirection build() => QuizDirection.deToHr;

  void set(QuizDirection value) => state = value;

  void toggle() => state = state == QuizDirection.deToHr
      ? QuizDirection.hrToDe
      : QuizDirection.deToHr;
}

final preferredDirectionProvider =
    NotifierProvider<PreferredDirection, QuizDirection>(PreferredDirection.new);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final svc = TtsService();
  ref.onDispose(svc.dispose);
  return svc;
});

final sttServiceProvider = Provider<SttService>((ref) {
  final svc = SttService();
  ref.onDispose(svc.cancel);
  return svc;
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

/// Anteil korrekt beantworteter Items pro Lektion für den aktuellen Spieler
/// (0.0–1.0). Reaktiv per Drift `watch` — aktualisiert sich automatisch nach
/// jeder neuen Antwort.
final lessonProgressProvider =
    StreamProvider.autoDispose<Map<String, double>>((ref) async* {
  final player = await ref.watch(currentPlayerProvider.future);
  yield* ref.watch(databaseProvider).watchLessonProgress(player.id);
});

/// Anzahl der Items, bei denen der aktuelle Spieler zuletzt falsch
/// geantwortet hat — Grundlage für die „Fehler ausbessern"-Karte.
final wrongItemsCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, lessonId) async {
  final player = await ref.watch(currentPlayerProvider.future);
  final items = await ref.watch(databaseProvider).wrongItemsForLesson(
        playerId: player.id,
        lessonId: lessonId,
      );
  return items.length;
});

final playerServiceProvider = Provider<PlayerService>((ref) {
  return PlayerService(ref.watch(databaseProvider));
});

final currentPlayerProvider = FutureProvider<Player>((ref) async {
  return ref.watch(playerServiceProvider).ensureDefaultPlayer();
});

final remoteLeaderboardServiceProvider =
    Provider<RemoteLeaderboardService>((ref) {
  return RemoteLeaderboardService(
    ref.watch(databaseProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, LeaderboardFilter>((ref, filter) async {
  return ref.watch(remoteLeaderboardServiceProvider).top(range: filter.range);
});

final sessionDetailServiceProvider = Provider<SessionDetailService>((ref) {
  return SessionDetailService(ref.watch(databaseProvider));
});

final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref.watch(databaseProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    ref.watch(databaseProvider),
    ref.watch(streakServiceProvider),
  );
});

final reminderEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  return ref.watch(databaseProvider).getReminderEnabled(player.id);
});

final playerStatsServiceProvider = Provider<PlayerStatsService>((ref) {
  return PlayerStatsService(ref.watch(databaseProvider));
});

final playerStatsProvider =
    FutureProvider.autoDispose<PlayerStats>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  return ref.watch(playerStatsServiceProvider).load(player.id);
});

final longestStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  return ref.watch(streakServiceProvider).longestStreak(player.id);
});

final currentStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  return ref.watch(streakServiceProvider).currentStreak(player.id);
});

/// True, wenn der nächste Quiz-Score durch das 7-Tage-Geschenk verdoppelt
/// wird. Wird nach jedem Quiz invalidiert (im `_finish`-Pfad).
final doublePointsActiveProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  final remaining =
      await ref.watch(databaseProvider).getDoublePointsRemaining(player.id);
  return remaining > 0;
});

final streakSaversProvider = FutureProvider.autoDispose<int>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  return ref.watch(databaseProvider).getStreakSavers(player.id);
});

class StreakDiagnostics {
  const StreakDiagnostics({
    required this.playerId,
    required this.finishedSessions,
    required this.unfinishedSessions,
    required this.distinctDays,
    required this.currentStreak,
    required this.now,
    required this.firestoreProfileStatus,
  });

  final String playerId;
  final int finishedSessions;
  final int unfinishedSessions;

  /// Sortiert absteigend (neuester Tag zuerst). Datum jeweils lokal.
  final List<DateTime> distinctDays;
  final int currentStreak;
  final DateTime now;

  /// Klartext-Status des Firestore-`users/{uid}`-Profils:
  /// "OK", "fehlt — bitte einmal abmelden und neu anmelden",
  /// "unvollständig (displayNameLower fehlt)", "nicht eingeloggt" oder
  /// "Fehler: …". Sichtbar im Diagnose-Block + im Copy-Text.
  final String firestoreProfileStatus;
}

final streakDiagnosticsProvider =
    FutureProvider.autoDispose<StreakDiagnostics>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  final db = ref.watch(databaseProvider);
  final finished = await db.finishedAtsForPlayer(player.id);
  final unfinished = await db.unfinishedSessionsCountForPlayer(player.id);
  final dayKeys = <int>{};
  final daySet = <DateTime>{};
  for (final ms in finished) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final key = d.year * 10000 + d.month * 100 + d.day;
    if (dayKeys.add(key)) daySet.add(DateTime(d.year, d.month, d.day));
  }
  final days = daySet.toList()..sort((a, b) => b.compareTo(a));
  final currentStreak =
      await ref.watch(streakServiceProvider).currentStreak(player.id);

  // Firestore-Profil-Status: prüft, ob das `users/{uid}`-Doc existiert
  // und die für die Friend-Suche nötigen Felder gesetzt sind.
  String profileStatus;
  final auth = ref.read(authStateProvider).value;
  if (auth == null) {
    profileStatus = 'nicht eingeloggt';
  } else if (!auth.emailVerified) {
    profileStatus = 'Email noch nicht bestätigt';
  } else {
    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(auth.uid)
          .get();
      if (!doc.exists) {
        profileStatus =
            'fehlt — bitte einmal abmelden und neu anmelden';
      } else {
        final data = doc.data() ?? const <String, dynamic>{};
        final hasLower = (data['displayNameLower'] as String?)?.isNotEmpty
            ?? false;
        final hasEmail = (data['email'] as String?)?.isNotEmpty ?? false;
        if (!hasLower) {
          profileStatus = 'unvollständig (displayNameLower fehlt)';
        } else if (!hasEmail) {
          profileStatus = 'unvollständig (email fehlt)';
        } else {
          profileStatus = 'OK';
        }
      }
    } catch (e) {
      profileStatus = 'Fehler: $e';
    }
  }

  return StreakDiagnostics(
    playerId: player.id,
    finishedSessions: finished.length,
    unfinishedSessions: unfinished,
    distinctDays: days,
    currentStreak: currentStreak,
    now: DateTime.now(),
    firestoreProfileStatus: profileStatus,
  );
});

final streakRewardCheckProvider =
    FutureProvider.autoDispose<StreakReward?>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  return ref.watch(streakServiceProvider).checkAndClaimReward(player.id);
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Auth-State des aktuellen Users. Nutzt `userChanges` (nicht
/// `authStateChanges`), damit Updates an `emailVerified`/`displayName` —
/// z. B. nach `reload()` oder externer Email-Bestätigung — auch beim
/// Listener ankommen.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionDetail?, String>((ref, sessionId) async {
  return ref.watch(sessionDetailServiceProvider).load(sessionId);
});

/// Heutige tägliche Challenge des aktuellen Spielers, null wenn noch nicht
/// gespielt. Wird vom `QuizSessionController._finish` nach Abschluss invalidiert.
final dailyChallengeTodayProvider =
    FutureProvider.autoDispose<DailyChallenge?>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  final db = ref.watch(databaseProvider);
  return db.getDailyChallenge(
    dateKey: dailyDateKey(DateTime.now()),
    playerId: player.id,
  );
});

/// Tagesauftrag (Mode + Bonus + Item-Pool) für den aktuellen Spieler.
/// Deterministisch aus (Datum, playerId) abgeleitet — bei wiederholtem
/// Aufruf am selben Tag identisch.
final dailyAssignmentProvider =
    FutureProvider.autoDispose<DailyAssignment?>((ref) async {
  final player = await ref.watch(currentPlayerProvider.future);
  final db = ref.watch(databaseProvider);
  return DailyAssigner(db)
      .assignFor(date: DateTime.now(), playerId: player.id);
});
