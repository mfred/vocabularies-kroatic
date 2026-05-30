import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/highscore/services/remote_leaderboard_service.dart';

/// Reine Unit-Tests der beiden Firestore-freien Aggregations-Helfer von
/// [RemoteLeaderboardService]. Sie sichern, dass der Scan-Fallback byte-gleich
/// zum bisherigen Verhalten aggregiert (Regressions-Guard) und dass das neue
/// `leaderboard_totals`-Mapping korrekt rankt — beides ohne Live-Firestore.
void main() {
  Map<String, dynamic> rawScore({
    required String uid,
    required int scorePoints,
    String? displayName,
  }) =>
      {
        'uid': uid,
        'scorePoints': scorePoints,
        'displayName': ?displayName,
      };

  Map<String, dynamic> totalDoc({
    required String uid,
    required int totalScorePoints,
    required int gamesPlayed,
    String? displayName,
  }) =>
      {
        'uid': uid,
        'totalScorePoints': totalScorePoints,
        'gamesPlayed': gamesPlayed,
        'displayName': ?displayName,
      };

  group('aggregateRawScores', () {
    test('summiert scorePoints pro uid und zählt Spiele', () {
      final out = RemoteLeaderboardService.aggregateRawScores([
        rawScore(uid: 'a', scorePoints: 20, displayName: 'Ana'),
        rawScore(uid: 'a', scorePoints: 10, displayName: 'Ana'),
        rawScore(uid: 'b', scorePoints: 5, displayName: 'Bao'),
      ]);
      expect(out.length, 2);
      expect(out[0].uid, 'a');
      expect(out[0].rank, 1);
      expect(out[0].totalScorePoints, 30);
      expect(out[0].gamesPlayed, 2);
      expect(out[1].uid, 'b');
      expect(out[1].rank, 2);
      expect(out[1].totalScorePoints, 5);
      expect(out[1].gamesPlayed, 1);
    });

    test('sortiert nach Punkten DESC, dann Spielzahl DESC', () {
      // Gleichstand bei 10 Punkten → mehr Spiele rankt höher.
      final out = RemoteLeaderboardService.aggregateRawScores([
        rawScore(uid: 'many', scorePoints: 5, displayName: 'M'),
        rawScore(uid: 'many', scorePoints: 5, displayName: 'M'),
        rawScore(uid: 'few', scorePoints: 10, displayName: 'F'),
      ]);
      expect(out.map((e) => e.uid).toList(), ['many', 'few']);
      expect(out[0].gamesPlayed, 2);
      expect(out[1].gamesPlayed, 1);
    });

    test('überspringt Dokumente ohne uid', () {
      final out = RemoteLeaderboardService.aggregateRawScores([
        rawScore(uid: '', scorePoints: 999, displayName: 'Geist'),
        {'scorePoints': 999, 'displayName': 'Fehlend'}, // uid fehlt ganz
        rawScore(uid: 'a', scorePoints: 7, displayName: 'Ana'),
      ]);
      expect(out.length, 1);
      expect(out.single.uid, 'a');
      expect(out.single.totalScorePoints, 7);
    });

    test('fehlende scorePoints → 0, leerer Name → "Anonym"', () {
      final out = RemoteLeaderboardService.aggregateRawScores([
        {'uid': 'a'}, // keine scorePoints, kein displayName
        rawScore(uid: 'a', scorePoints: 4, displayName: '   '),
      ]);
      expect(out.single.totalScorePoints, 4);
      expect(out.single.gamesPlayed, 2);
      expect(out.single.displayName, 'Anonym');
    });

    test('displayName: erster (= jüngster) Treffer pro uid gewinnt', () {
      // Input ist finishedAt-DESC — der neueste Name steht oben.
      final out = RemoteLeaderboardService.aggregateRawScores([
        rawScore(uid: 'a', scorePoints: 1, displayName: 'Neu'),
        rawScore(uid: 'a', scorePoints: 1, displayName: 'Alt'),
      ]);
      expect(out.single.displayName, 'Neu');
    });

    test('limit schneidet ab und Ränge sind 1..limit fortlaufend', () {
      final docs = [
        for (var i = 0; i < 5; i++)
          rawScore(uid: 'u$i', scorePoints: 100 - i, displayName: 'U$i'),
      ];
      final out = RemoteLeaderboardService.aggregateRawScores(docs, limit: 3);
      expect(out.length, 3);
      expect(out.map((e) => e.rank).toList(), [1, 2, 3]);
      expect(out.map((e) => e.uid).toList(), ['u0', 'u1', 'u2']);
    });

    test('leerer Input → leere Liste', () {
      expect(RemoteLeaderboardService.aggregateRawScores([]), isEmpty);
    });
  });

  group('mapTotalsDocs', () {
    test('reicht Felder durch, vergibt Ränge, respektiert limit', () {
      final out = RemoteLeaderboardService.mapTotalsDocs([
        totalDoc(
            uid: 'a', totalScorePoints: 90, gamesPlayed: 9, displayName: 'Ana'),
        totalDoc(
            uid: 'b', totalScorePoints: 80, gamesPlayed: 8, displayName: 'Bao'),
        totalDoc(
            uid: 'c', totalScorePoints: 70, gamesPlayed: 7, displayName: 'Cic'),
      ], limit: 2);
      expect(out.length, 2);
      expect(out[0].uid, 'a');
      expect(out[0].rank, 1);
      expect(out[0].totalScorePoints, 90);
      expect(out[0].gamesPlayed, 9);
      expect(out[0].displayName, 'Ana');
      expect(out[1].uid, 'b');
      expect(out[1].rank, 2);
    });

    test('sortiert selbst (Punkte DESC) auch bei gemischtem Input', () {
      // Bewusst NICHT vorsortiert → beweist die defensive Eigen-Sortierung.
      final out = RemoteLeaderboardService.mapTotalsDocs([
        totalDoc(uid: 'mid', totalScorePoints: 50, gamesPlayed: 5),
        totalDoc(uid: 'top', totalScorePoints: 99, gamesPlayed: 1),
        totalDoc(uid: 'low', totalScorePoints: 10, gamesPlayed: 9),
      ]);
      expect(out.map((e) => e.uid).toList(), ['top', 'mid', 'low']);
      expect(out.map((e) => e.rank).toList(), [1, 2, 3]);
    });

    test('leere Totals-Liste → leer (das Fallback-Signal von top())', () {
      // top() wählt bei isEmpty den Scan-Pfad — diese Leere ist Vertrag.
      expect(RemoteLeaderboardService.mapTotalsDocs([]), isEmpty);
    });

    test('überspringt malformte Docs, fehlende Zahlen → 0', () {
      final out = RemoteLeaderboardService.mapTotalsDocs([
        {'totalScorePoints': 100, 'gamesPlayed': 3}, // uid fehlt → skip
        totalDoc(uid: '', totalScorePoints: 100, gamesPlayed: 3), // leer → skip
        {'uid': 'a'}, // Zahlen fehlen → 0/0
      ]);
      expect(out.length, 1);
      expect(out.single.uid, 'a');
      expect(out.single.totalScorePoints, 0);
      expect(out.single.gamesPlayed, 0);
      expect(out.single.displayName, 'Anonym');
    });

    test('Gleichstand bei Punkten → mehr Spiele rankt höher', () {
      final out = RemoteLeaderboardService.mapTotalsDocs([
        totalDoc(uid: 'few', totalScorePoints: 40, gamesPlayed: 2),
        totalDoc(uid: 'many', totalScorePoints: 40, gamesPlayed: 9),
      ]);
      expect(out.map((e) => e.uid).toList(), ['many', 'few']);
    });
  });
}
