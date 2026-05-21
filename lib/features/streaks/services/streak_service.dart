import '../../../core/database/database.dart' hide StreakReward;
import '../models/streak_reward.dart';

class StreakService {
  StreakService(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<int> currentStreak(String playerId) async {
    final timestamps = await _db.finishedAtsForPlayer(playerId);
    return _computeCurrentStreak(timestamps, _clock());
  }

  Future<int> longestStreak(String playerId) async {
    final timestamps = await _db.finishedAtsForPlayer(playerId);
    return _computeLongestStreak(timestamps);
  }

  /// Prüft, ob der heutige Tag im aktuellen Streak einen Meilenstein erreicht
  /// hat, der noch nicht gut­geschrieben wurde. Falls ja: vergibt den Bonus,
  /// addiert ihn auf `pendingBonusPoints` des Spielers und gibt den Reward
  /// zurück. Sonst null.
  Future<StreakReward?> checkAndClaimReward(String playerId) async {
    final streak = await currentStreak(playerId);
    final bonus = bonusForStreakDay(streak);
    if (bonus == null) return null;
    if (await _db.hasClaimedStreakReward(playerId, streak)) return null;
    await _db.insertStreakReward(StreakRewardsCompanion.insert(
      playerId: playerId,
      streakDay: streak,
      claimedAt: _clock().millisecondsSinceEpoch,
      bonusPoints: bonus,
    ));
    await _db.addPendingBonusPoints(playerId, bonus);
    return StreakReward(streakDay: streak, bonusPoints: bonus);
  }

  /// Sichtbar für Tests.
  static int computeCurrentStreak(List<int> finishedAtsMs, DateTime now) =>
      _computeCurrentStreak(finishedAtsMs, now);

  static int computeLongestStreak(List<int> finishedAtsMs) =>
      _computeLongestStreak(finishedAtsMs);
}

int _dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

Set<int> _distinctDayKeys(List<int> finishedAtsMs) {
  final out = <int>{};
  for (final ms in finishedAtsMs) {
    out.add(_dayKey(DateTime.fromMillisecondsSinceEpoch(ms)));
  }
  return out;
}

int _computeCurrentStreak(List<int> finishedAtsMs, DateTime now) {
  if (finishedAtsMs.isEmpty) return 0;
  final days = _distinctDayKeys(finishedAtsMs);
  final today = DateTime(now.year, now.month, now.day);
  // Wenn heute nichts gespielt wurde, beginnt der „aktuelle" Streak bei gestern,
  // damit ein an einem Tag begonnener Streak nicht sofort ab Mitternacht
  // verloren geht. (User hat 24h+ Toleranz; Bruch erst, wenn auch gestern leer.)
  var cursor = today;
  if (!days.contains(_dayKey(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    if (!days.contains(_dayKey(cursor))) return 0;
  }
  var streak = 0;
  while (days.contains(_dayKey(cursor))) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

int _computeLongestStreak(List<int> finishedAtsMs) {
  if (finishedAtsMs.isEmpty) return 0;
  final daysSorted = _distinctDayKeys(finishedAtsMs).toList()..sort();
  final dates = daysSorted
      .map((k) => DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100))
      .toList();
  var longest = 1;
  var current = 1;
  for (var i = 1; i < dates.length; i++) {
    final diff = dates[i].difference(dates[i - 1]).inDays;
    if (diff == 1) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }
  return longest;
}
