import 'duel_pair.dart';
import 'duel_run_result.dart';

enum DuelStatus { pending, accepted, declined, completed, expired }

DuelStatus _statusFromString(String? s) {
  switch (s) {
    case 'accepted':
      return DuelStatus.accepted;
    case 'declined':
      return DuelStatus.declined;
    case 'completed':
      return DuelStatus.completed;
    case 'expired':
      return DuelStatus.expired;
    default:
      return DuelStatus.pending;
  }
}

String duelStatusToString(DuelStatus s) {
  switch (s) {
    case DuelStatus.pending:
      return 'pending';
    case DuelStatus.accepted:
      return 'accepted';
    case DuelStatus.declined:
      return 'declined';
    case DuelStatus.completed:
      return 'completed';
    case DuelStatus.expired:
      return 'expired';
  }
}

/// Ergebnis eines Duell-Spielers innerhalb eines Firestore-Duels.
class DuelPlayerResult {
  const DuelPlayerResult({
    required this.roundsMs,
    required this.penaltiesMs,
    required this.totalMs,
    required this.finishedAtMs,
  });

  final List<int> roundsMs;
  final List<int> penaltiesMs;
  final int totalMs;
  final int finishedAtMs;

  Map<String, dynamic> toMap() => {
        'roundsMs': roundsMs,
        'penaltiesMs': penaltiesMs,
        'totalMs': totalMs,
        'finishedAtMs': finishedAtMs,
      };

  factory DuelPlayerResult.fromMap(Map<String, dynamic> map) =>
      DuelPlayerResult(
        roundsMs: (map['roundsMs'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        penaltiesMs: (map['penaltiesMs'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        totalMs: (map['totalMs'] as num?)?.toInt() ?? 0,
        finishedAtMs: (map['finishedAtMs'] as num?)?.toInt() ?? 0,
      );

  factory DuelPlayerResult.fromRun(DuelRunResult run) => DuelPlayerResult(
        roundsMs: List<int>.from(run.roundsMs),
        penaltiesMs: List<int>.from(run.penaltiesMs),
        totalMs: run.totalMs,
        finishedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

class Duel {
  const Duel({
    required this.id,
    required this.challengerUid,
    required this.challengerDisplayName,
    required this.opponentUid,
    required this.opponentDisplayName,
    required this.lessonId,
    required this.lessonTitle,
    required this.direction,
    required this.status,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.rounds,
    required this.challengerResult,
    this.opponentResult,
    this.winnerUid,
  });

  final String id;
  final String challengerUid;
  final String challengerDisplayName;
  final String opponentUid;
  final String opponentDisplayName;
  final String lessonId;
  final String lessonTitle;
  final String direction;
  final DuelStatus status;
  final int createdAtMs;
  final int expiresAtMs;
  final List<DuelRound> rounds;
  final DuelPlayerResult challengerResult;
  final DuelPlayerResult? opponentResult;
  final String? winnerUid;

  bool get isPending => status == DuelStatus.pending;
  bool get isAccepted => status == DuelStatus.accepted;
  bool get isCompleted => status == DuelStatus.completed;

  /// Berechnet ob das Duell abgelaufen ist (clientseitig — Backend kann das
  /// nicht setzen ohne Cloud-Function, wir leiten es aus expiresAtMs ab).
  bool get isExpiredClientSide =>
      status != DuelStatus.completed &&
      DateTime.now().millisecondsSinceEpoch > expiresAtMs;

  Map<String, dynamic> toCreateMap() => {
        'challengerUid': challengerUid,
        'challengerDisplayName': challengerDisplayName,
        'opponentUid': opponentUid,
        'opponentDisplayName': opponentDisplayName,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'direction': direction,
        'status': duelStatusToString(status),
        'createdAtMs': createdAtMs,
        'expiresAtMs': expiresAtMs,
        'rounds': [for (final r in rounds) r.toMap()],
        'challengerResult': challengerResult.toMap(),
      };

  factory Duel.fromMap(String id, Map<String, dynamic> map) {
    return Duel(
      id: id,
      challengerUid: map['challengerUid'] as String? ?? '',
      challengerDisplayName: map['challengerDisplayName'] as String? ?? '',
      opponentUid: map['opponentUid'] as String? ?? '',
      opponentDisplayName: map['opponentDisplayName'] as String? ?? '',
      lessonId: map['lessonId'] as String? ?? '',
      lessonTitle: map['lessonTitle'] as String? ?? '',
      direction: map['direction'] as String? ?? 'de_hr',
      status: _statusFromString(map['status'] as String?),
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      expiresAtMs: (map['expiresAtMs'] as num?)?.toInt() ?? 0,
      rounds: [
        for (final m in (map['rounds'] as List? ?? const []))
          DuelRound.fromMap(Map<String, dynamic>.from(m as Map)),
      ],
      challengerResult: DuelPlayerResult.fromMap(
        Map<String, dynamic>.from(
            map['challengerResult'] as Map? ?? const {}),
      ),
      opponentResult: map['opponentResult'] == null
          ? null
          : DuelPlayerResult.fromMap(
              Map<String, dynamic>.from(map['opponentResult'] as Map),
            ),
      winnerUid: map['winnerUid'] as String?,
    );
  }
}
