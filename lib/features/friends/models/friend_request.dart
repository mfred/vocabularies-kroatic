enum FriendRequestStatus { pending, accepted, declined, cancelled }

FriendRequestStatus _statusFromString(String? s) {
  switch (s) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'declined':
      return FriendRequestStatus.declined;
    case 'cancelled':
      return FriendRequestStatus.cancelled;
    default:
      return FriendRequestStatus.pending;
  }
}

String statusToString(FriendRequestStatus s) {
  switch (s) {
    case FriendRequestStatus.pending:
      return 'pending';
    case FriendRequestStatus.accepted:
      return 'accepted';
    case FriendRequestStatus.declined:
      return 'declined';
    case FriendRequestStatus.cancelled:
      return 'cancelled';
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromDisplayName,
    required this.status,
    required this.createdAtMs,
    this.respondedAtMs,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromDisplayName;
  final FriendRequestStatus status;
  final int createdAtMs;
  final int? respondedAtMs;

  factory FriendRequest.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequest(
      id: id,
      fromUid: map['fromUid'] as String? ?? '',
      toUid: map['toUid'] as String? ?? '',
      fromDisplayName: map['fromDisplayName'] as String? ?? '',
      status: _statusFromString(map['status'] as String?),
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      respondedAtMs: (map['respondedAtMs'] as num?)?.toInt(),
    );
  }
}

/// `pairKey` für `friendships/{pairKey}`. Sortiert die UIDs lexikographisch,
/// damit eine Freundschaft genau ein Dokument hat (unabhängig davon, wer
/// gesendet hat).
String friendshipPairKey(String a, String b) {
  return a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';
}
