import '../../../core/database/database.dart' hide StreakReward;
import '../models/streak_reward.dart';

/// Max. wie viele Streak-Schoner gleichzeitig im Reservoir liegen dürfen.
/// Pro 7-Tage-Meilenstein wird einer gutgeschrieben (gecapped).
const int kMaxStreakSavers = 3;

class StreakService {
  StreakService(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Liefert den aktuellen Streak inkl. ggf. durch Schoner überbrückter Tage.
  /// REIN LESEND und idempotent — der tatsächliche Schoner-Verbrauch wird hier
  /// NICHT persistiert (das übernimmt [settleStreakSavers] nach einem
  /// abgeschlossenen Quiz). Früher konsumierte diese Methode Schoner direkt,
  /// wodurch ein Hintergrund-/Kaltstart-Read (Reminder-Reschedule) sie still
  /// verbrannte und zwei aufeinanderfolgende Reads inkonsistente Werte lieferten.
  Future<int> currentStreak(String playerId) async {
    final timestamps = await _db.finishedAtsForPlayer(playerId);
    final savers = await _db.getStreakSavers(playerId);
    return _computeCurrentStreak(timestamps, _clock(), savers).streak;
  }

  /// Persistiert den tatsächlichen Schoner-Verbrauch des aktuellen Streaks —
  /// höchstens einmal pro Kalendertag. Wird ausschließlich nach einem
  /// abgeschlossenen Quiz aufgerufen, nie beim bloßen Lesen.
  ///
  /// Idempotenz: Der Tagesschlüssel in [Players.lastSaverConsumedDayKey]
  /// verhindert, dass mehrere Sessions am selben Tag denselben Schoner doppelt
  /// abziehen. Über Tage hinweg verhindert das schrittweise Reduzieren des
  /// Reservoirs, dass dieselbe (bereits bezahlte) Lücke erneut bezahlt wird.
  Future<void> settleStreakSavers(String playerId) async {
    final savers = await _db.getStreakSavers(playerId);
    if (savers == 0) return;
    final timestamps = await _db.finishedAtsForPlayer(playerId);
    final consumed = _computeCurrentStreak(timestamps, _clock(), savers)
        .consumed
        .clamp(0, savers);
    if (consumed <= 0) return;
    final todayKey = _dayKey(_clock());
    if (await _db.getLastSaverConsumedDayKey(playerId) == todayKey) return;
    await _db.consumeStreakSavers(playerId, consumed);
    await _db.setLastSaverConsumedDayKey(playerId, todayKey);
  }

  Future<int> longestStreak(String playerId) async {
    final timestamps = await _db.finishedAtsForPlayer(playerId);
    return _computeLongestStreak(timestamps);
  }

  /// Prüft, ob der heutige Tag im aktuellen Streak einen Meilenstein erreicht
  /// hat, der noch nicht gut­geschrieben wurde. Falls ja: vergibt Bonus +
  /// (auf Tag 7) zusätzliches dreiteiliges Geschenk (Saver + Doppel-Punkte).
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
    if (streak == 7) {
      // Dreiteiliges 7-Tage-Geschenk: Bonus oben + Saver + Doppel-Punkte.
      await _db.incrementStreakSavers(playerId, cap: kMaxStreakSavers);
      await _db.grantDoublePoints(playerId);
    }
    return StreakReward(streakDay: streak, bonusPoints: bonus);
  }

  /// Sichtbar für Tests — natürlicher Streak ohne Saver.
  static int computeCurrentStreak(List<int> finishedAtsMs, DateTime now) =>
      _computeCurrentStreak(finishedAtsMs, now, 0).streak;

  /// Sichtbar für Tests — Streak mit Saver-Reservoir.
  static StreakWithConsumption computeCurrentStreakWithSavers(
    List<int> finishedAtsMs,
    DateTime now,
    int savers,
  ) =>
      _computeCurrentStreak(finishedAtsMs, now, savers);

  static int computeLongestStreak(List<int> finishedAtsMs) =>
      _computeLongestStreak(finishedAtsMs);
}

/// Ergebnis der Streak-Berechnung mit Saver-Buchhaltung.
class StreakWithConsumption {
  const StreakWithConsumption(this.streak, this.consumed);
  final int streak;
  final int consumed;
}

int _dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

Set<int> _distinctDayKeys(List<int> finishedAtsMs) {
  final out = <int>{};
  for (final ms in finishedAtsMs) {
    out.add(_dayKey(DateTime.fromMillisecondsSinceEpoch(ms)));
  }
  return out;
}

StreakWithConsumption _computeCurrentStreak(
  List<int> finishedAtsMs,
  DateTime now,
  int availableSavers,
) {
  if (finishedAtsMs.isEmpty) return const StreakWithConsumption(0, 0);
  final days = _distinctDayKeys(finishedAtsMs);
  final today = DateTime(now.year, now.month, now.day);
  var cursor = today;
  var savers = availableSavers;
  var consumed = 0;
  // Toleranz für „heute noch nicht gespielt": gestern darf auch zählen,
  // sonst bricht jeder Streak ab Mitternacht.
  if (!days.contains(_dayKey(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    if (!days.contains(_dayKey(cursor))) {
      // Auch gestern leer — versuche Saver einzusetzen.
      if (savers <= 0) return const StreakWithConsumption(0, 0);
      // Saver kann die heutige Lücke decken; wir starten ab gestern
      // (oder vorgestern, falls auch gestern leer) — aber nur, wenn dort
      // tatsächlich gespielt wurde.
      // Schließen einer 1-Tag-Lücke ab "today" und "yesterday" leer:
      // Saver wirkt für genau einen Tag — falls auch vorgestern leer ist,
      // hat der Saver nichts zu retten.
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!days.contains(_dayKey(cursor))) {
        return const StreakWithConsumption(0, 0);
      }
      savers--;
      consumed++;
    }
  }
  var streak = 0;
  while (true) {
    if (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      continue;
    }
    // Lücke — kann Saver sie decken?
    if (savers > 0) {
      // Vor-Sprung: Saver deckt diesen einen Tag, gehe einen Tag weiter.
      savers--;
      consumed++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      if (!days.contains(_dayKey(cursor))) {
        // Hinter dem Saver-gedeckten Tag steckt schon wieder eine Lücke
        // — kein weiterer Save mehr für direkt-aneinander, abbrechen.
        break;
      }
      // Sonst: weiter zählen ab gedeckter Position.
      continue;
    }
    break;
  }
  return StreakWithConsumption(streak, consumed);
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
