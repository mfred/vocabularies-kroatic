import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/database/database.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_range.dart';

class RemoteLeaderboardService {
  RemoteLeaderboardService(this._db, this._firestore, this._auth);

  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Schutzobergrenze für die rohe Score-Liste pro Range. Über alles
  /// hinausgehende wird nicht aggregiert.
  static const int _rawFetchCap = 2000;

  CollectionReference<Map<String, dynamic>> get _scores =>
      _firestore.collection('scores');

  /// Server-gepflegtes Aggregat (von der `aggregateScore`-Cloud-Function
  /// fortgeschrieben): eine Zeile je `uid` mit Summe der Punkte und Spielzahl.
  CollectionReference<Map<String, dynamic>> get _totals =>
      _firestore.collection('leaderboard_totals');

  /// Lädt eine bereits abgeschlossene lokale Session ins Firestore-`scores`-
  /// Document mit derselben ID hoch. Fehlende Auth oder Session werden still
  /// übersprungen (Offline-first-Prinzip).
  Future<void> uploadSession(String sessionId) async {
    final user = _auth.currentUser;
    // Nur verifizierte Accounts dürfen in die globale Bestenliste schreiben —
    // konsistent zum übrigen Double-Opt-In-Gating und zur Firestore-Rule
    // (email_verified). Unverifizierte Wegwerf-Accounts bleiben draußen.
    if (user == null || !user.emailVerified) return;
    final session = await _db.getQuizSession(sessionId);
    if (session == null || session.finishedAt == null) return;
    final data = {
      'uid': user.uid,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email ?? 'Anonym'),
      'lessonId': session.lessonId,
      'direction': session.direction,
      'format': _formatFromMode(session.mode),
      'scorePoints': session.scorePoints,
      'correctCount': session.correctCount,
      'totalCount': session.totalCount,
      'durationMs': session.durationMs ?? 0,
      'hintsUsed': session.hintsUsed,
      'finishedAt': Timestamp.fromMillisecondsSinceEpoch(session.finishedAt!),
    };
    await _scores.doc(sessionId).set(data);
  }

  /// Liefert die Top-`limit` aggregierten Einträge pro Spieler (eine Zeile
  /// je `uid` mit Summe der `scorePoints` und Anzahl Spiele).
  ///
  /// Für die „Ewig"-Liste wird zuerst das server-gepflegte Aggregat
  /// `leaderboard_totals` gelesen (O(`limit`) statt bis zu [_rawFetchCap]
  /// Score-Docs zu scannen — Audit-Befund M9). Ist das Aggregat (noch) leer
  /// oder nicht lesbar — etwa weil die `aggregateScore`-Cloud-Function bzw. die
  /// Firestore-Rules noch nicht deployt sind —, fällt die Methode still auf den
  /// bisherigen Roh-Scan zurück. Der Scan ist immer ein gültiger Pfad, daher
  /// ist das Schlucken des Lesefehlers unbedenklich (Offline-first). Die
  /// Zeitfenster (Heute/Woche/Monat) haben noch keine Aggregat-Buckets und
  /// nutzen weiterhin den Scan.
  Future<List<LeaderboardEntry>> top({
    required LeaderboardRange range,
    int limit = 50,
  }) async {
    if (range == LeaderboardRange.allTime) {
      try {
        final fromTotals = await _topFromTotals(limit);
        if (fromTotals.isNotEmpty) return fromTotals;
        // Aggregat leer (Function noch nicht deployt / noch nicht befüllt) →
        // Fallback unten auf den Roh-Scan, damit die Liste nie leer wirkt.
      } catch (_) {
        // Aggregat nicht lesbar (permission-denied/unavailable/offline) →
        // ebenfalls Fallback auf den Roh-Scan.
      }
    }
    return _topFromScores(range, limit);
  }

  /// Liest die „Ewig"-Liste aus dem server-gepflegten Aggregat
  /// `leaderboard_totals` (eine Zeile je `uid`, bereits server-sortiert).
  Future<List<LeaderboardEntry>> _topFromTotals(int limit) async {
    final snap = await _totals
        .orderBy('totalScorePoints', descending: true)
        .limit(limit)
        .get();
    return mapTotalsDocs(snap.docs.map((d) => d.data()).toList(), limit: limit);
  }

  /// Roh-Scan der `scores`-Collection mit clientseitiger Aggregation pro `uid`
  /// (bisheriges Verhalten; deckt die Zeitfenster und den Ewig-Fallback ab).
  Future<List<LeaderboardEntry>> _topFromScores(
      LeaderboardRange range, int limit) async {
    final bounds = range.boundsNow();
    Query<Map<String, dynamic>> q = _scores;
    if (range != LeaderboardRange.allTime) {
      q = q.where('finishedAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromMillisecondsSinceEpoch(bounds.sinceMs));
    }
    q = q.orderBy('finishedAt', descending: true).limit(_rawFetchCap);
    final snap = await q.get();
    return aggregateRawScores(snap.docs.map((d) => d.data()).toList(),
        limit: limit);
  }

  /// Aggregiert rohe `scores`-Dokumente clientseitig pro `uid` (Summe der
  /// `scorePoints`, Anzahl Spiele) und liefert die Top-`limit`-Einträge,
  /// sortiert nach Punkten DESC, dann Spielzahl DESC.
  ///
  /// Pure Funktion (kein Firestore) — Unit-Test-Oberfläche. [rawDocs] werden in
  /// `finishedAt`-DESC-Reihenfolge erwartet, damit der Anzeigename beim ersten
  /// (= jüngsten) Treffer pro `uid` übernommen wird.
  static List<LeaderboardEntry> aggregateRawScores(
    List<Map<String, dynamic>> rawDocs, {
    int limit = 50,
  }) {
    final perUser = <String, _Aggregate>{};
    for (final d in rawDocs) {
      final uid = (d['uid'] as String?) ?? '';
      if (uid.isEmpty) continue;
      final points = (d['scorePoints'] as num?)?.toInt() ?? 0;
      final name = (d['displayName'] as String?)?.trim().isNotEmpty == true
          ? (d['displayName'] as String).trim()
          : 'Anonym';
      final agg = perUser.putIfAbsent(
        uid,
        () => _Aggregate(displayName: name),
      );
      agg.totalScorePoints += points;
      agg.gamesPlayed += 1;
      // Neuester Eintrag steht durch finishedAt DESC oben — beim ersten
      // Treffer pro uid übernehmen wir dessen Anzeigenamen.
      agg.displayName ??= name;
    }

    final sorted = perUser.entries.toList()
      ..sort((a, b) {
        final byPoints =
            b.value.totalScorePoints.compareTo(a.value.totalScorePoints);
        if (byPoints != 0) return byPoints;
        return b.value.gamesPlayed.compareTo(a.value.gamesPlayed);
      });

    final out = <LeaderboardEntry>[];
    for (var i = 0; i < sorted.length && i < limit; i++) {
      final e = sorted[i];
      out.add(LeaderboardEntry(
        rank: i + 1,
        uid: e.key,
        displayName: e.value.displayName ?? 'Anonym',
        totalScorePoints: e.value.totalScorePoints,
        gamesPlayed: e.value.gamesPlayed,
      ));
    }
    return out;
  }

  /// Mappt `leaderboard_totals`-Dokumente auf [LeaderboardEntry]. Pure Funktion
  /// (kein Firestore) — Unit-Test-Oberfläche. Sortiert defensiv selbst (Punkte
  /// DESC, dann Spielzahl DESC), bleibt damit unabhängig von der Firestore-
  /// `orderBy` robust und mit gemischtem Test-Input prüfbar. Dokumente ohne
  /// `uid` werden übersprungen; fehlende Zahlenfelder gelten als 0.
  static List<LeaderboardEntry> mapTotalsDocs(
    List<Map<String, dynamic>> totalsDocs, {
    int limit = 50,
  }) {
    final rows =
        <({String uid, String displayName, int points, int games})>[];
    for (final d in totalsDocs) {
      final uid = (d['uid'] as String?) ?? '';
      if (uid.isEmpty) continue;
      final name = (d['displayName'] as String?)?.trim().isNotEmpty == true
          ? (d['displayName'] as String).trim()
          : 'Anonym';
      rows.add((
        uid: uid,
        displayName: name,
        points: (d['totalScorePoints'] as num?)?.toInt() ?? 0,
        games: (d['gamesPlayed'] as num?)?.toInt() ?? 0,
      ));
    }

    rows.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      return b.games.compareTo(a.games);
    });

    final out = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length && i < limit; i++) {
      final r = rows[i];
      out.add(LeaderboardEntry(
        rank: i + 1,
        uid: r.uid,
        displayName: r.displayName,
        totalScorePoints: r.points,
        gamesPlayed: r.games,
      ));
    }
    return out;
  }

  String _formatFromMode(String mode) {
    // mode = "<format>_<direction>" → format = "mc" / "type" / "speak" / "listen"
    final underscore = mode.indexOf('_');
    return underscore == -1 ? mode : mode.substring(0, underscore);
  }
}

class _Aggregate {
  _Aggregate({this.displayName});

  String? displayName;
  int totalScorePoints = 0;
  int gamesPlayed = 0;
}
