import 'package:cloud_firestore/cloud_firestore.dart';

import '../../quiz/models/quiz_direction.dart';
import '../models/duel.dart';
import '../models/duel_pair.dart';
import '../models/duel_run_result.dart';

const Duration kDuelExpiry = Duration(days: 7);

class DuelService {
  DuelService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _duels =>
      _firestore.collection('duels');

  /// Erstellt eine neue Challenge nach dem Challenger-Lauf. Set + Challenger-
  /// Ergebnis werden direkt mitgeschrieben; Status = pending.
  Future<String> createChallenge({
    required String challengerUid,
    required String challengerDisplayName,
    required String opponentUid,
    required String opponentDisplayName,
    required String lessonId,
    required String lessonTitle,
    required QuizDirection direction,
    required List<DuelRound> rounds,
    required DuelRunResult challengerRun,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final duel = Duel(
      id: '',
      challengerUid: challengerUid,
      challengerDisplayName: challengerDisplayName,
      opponentUid: opponentUid,
      opponentDisplayName: opponentDisplayName,
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      direction: direction.code,
      status: DuelStatus.pending,
      createdAtMs: now,
      expiresAtMs: now + kDuelExpiry.inMilliseconds,
      rounds: rounds,
      challengerResult: DuelPlayerResult.fromRun(challengerRun),
    );
    final ref = await _duels.add(duel.toCreateMap());
    return ref.id;
  }

  Stream<Duel?> watch(String duelId) {
    return _duels.doc(duelId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Duel.fromMap(duelId, snap.data() ?? {});
    });
  }

  Stream<List<Duel>> watchIncomingPending(String uid) {
    return _duels
        .where('opponentUid', isEqualTo: uid)
        .where('status', isEqualTo: duelStatusToString(DuelStatus.pending))
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs) Duel.fromMap(d.id, d.data()),
            ]);
  }

  Stream<List<Duel>> watchMyPendingChallenges(String uid) {
    return _duels
        .where('challengerUid', isEqualTo: uid)
        .where('status', isEqualTo: duelStatusToString(DuelStatus.pending))
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs) Duel.fromMap(d.id, d.data()),
            ]);
  }

  /// Streamt alle neu abgeschlossenen Duelle, in denen ich Challenger war.
  /// Wird für den Status-Hinweis genutzt (kommt in Iter 25).
  Stream<List<Duel>> watchRecentlyCompletedForChallenger(String uid) {
    return _duels
        .where('challengerUid', isEqualTo: uid)
        .where('status', isEqualTo: duelStatusToString(DuelStatus.completed))
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs) Duel.fromMap(d.id, d.data()),
            ]);
  }

  Future<void> acceptDuel(String duelId) async {
    await _duels.doc(duelId).update({
      'status': duelStatusToString(DuelStatus.accepted),
    });
  }

  Future<void> declineDuel(String duelId) async {
    await _duels.doc(duelId).update({
      'status': duelStatusToString(DuelStatus.declined),
    });
  }

  /// Schreibt das Opponent-Ergebnis und bestimmt den Gewinner.
  Future<void> submitOpponentResult({
    required String duelId,
    required DuelRunResult opponentRun,
    required int challengerTotalMs,
    required String challengerUid,
    required String opponentUid,
  }) async {
    final result = DuelPlayerResult.fromRun(opponentRun);
    final String winnerUid;
    if (result.totalMs < challengerTotalMs) {
      winnerUid = opponentUid;
    } else if (result.totalMs > challengerTotalMs) {
      winnerUid = challengerUid;
    } else {
      // Identische Zeiten → Challenger gewinnt (er war zuerst).
      winnerUid = challengerUid;
    }
    await _duels.doc(duelId).update({
      'status': duelStatusToString(DuelStatus.completed),
      'opponentResult': result.toMap(),
      'winnerUid': winnerUid,
    });
  }
}
