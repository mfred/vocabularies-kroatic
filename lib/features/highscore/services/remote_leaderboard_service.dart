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

  /// Lädt eine bereits abgeschlossene lokale Session ins Firestore-`scores`-
  /// Document mit derselben ID hoch. Fehlende Auth oder Session werden still
  /// übersprungen (Offline-first-Prinzip).
  Future<void> uploadSession(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return;
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
  Future<List<LeaderboardEntry>> top({
    required LeaderboardRange range,
    int limit = 50,
  }) async {
    final bounds = range.boundsNow();
    Query<Map<String, dynamic>> q = _scores;
    if (range != LeaderboardRange.allTime) {
      q = q.where('finishedAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromMillisecondsSinceEpoch(bounds.sinceMs));
    }
    q = q.orderBy('finishedAt', descending: true).limit(_rawFetchCap);
    final snap = await q.get();

    final perUser = <String, _Aggregate>{};
    for (final doc in snap.docs) {
      final d = doc.data();
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
      // Neuester Eintrag steht durch orderBy finishedAt DESC oben — beim
      // ersten Treffer pro uid übernehmen wir dessen Anzeigenamen.
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
