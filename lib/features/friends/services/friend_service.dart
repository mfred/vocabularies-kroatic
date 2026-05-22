import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend_request.dart';
import '../models/user_profile.dart';

class FriendService {
  FriendService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection('friendships');

  /// Eine Anfrage senden. Erlaubt nur, wenn aktuell keine offene Anfrage in
  /// die gleiche Richtung existiert.
  Future<void> sendRequest({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
  }) async {
    if (fromUid == toUid) {
      throw StateError('Du kannst dir selbst keine Anfrage senden.');
    }
    // Vorab-Checks dürfen den eigentlichen `add` nicht blockieren, wenn sie
    // wegen Firestore-Rules permission-denied liefern. Sie sind nur UX-Hinweise.
    try {
      if (await areFriends(fromUid, toUid)) {
        throw StateError('Ihr seid bereits befreundet.');
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // Permission-Error o.ä. beim Existenz-Check ignorieren.
    }
    try {
      final existing = await _requests
          .where('fromUid', isEqualTo: fromUid)
          .where('toUid', isEqualTo: toUid)
          .where('status',
              isEqualTo: statusToString(FriendRequestStatus.pending))
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw StateError('Du hast bereits eine offene Anfrage gesendet.');
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // Permission-Error o.ä. ignorieren — der `add` unten wird ggf. den
      // ehrlichen Fehler zurückliefern.
    }
    await _requests.add({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromDisplayName': fromDisplayName,
      'status': statusToString(FriendRequestStatus.pending),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool> areFriends(String a, String b) async {
    final key = friendshipPairKey(a, b);
    try {
      final snap = await _friendships.doc(key).get();
      return snap.exists;
    } catch (_) {
      // Permission-Denied bei nicht-existentem Doc (Rule scheitert weil
      // resource.data.uids undefined ist) wird hier abgefangen. Wir nehmen
      // "nicht befreundet" an — falsche Annahme wird beim Add weitergereicht.
      return false;
    }
  }

  Stream<List<FriendRequest>> watchIncoming(String uid) {
    return _requests
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: statusToString(FriendRequestStatus.pending))
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs) FriendRequest.fromMap(d.id, d.data()),
            ]);
  }

  Stream<List<FriendRequest>> watchOutgoing(String uid) {
    return _requests
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: statusToString(FriendRequestStatus.pending))
        .snapshots()
        .map((snap) => [
              for (final d in snap.docs) FriendRequest.fromMap(d.id, d.data()),
            ]);
  }

  /// Stream aller `pairKey`s, die einen UID enthalten.
  Stream<List<String>> watchFriendUids(String myUid) {
    return _friendships
        .where('uids', arrayContains: myUid)
        .snapshots()
        .map((snap) {
      final ids = <String>[];
      for (final doc in snap.docs) {
        final uids = (doc.data()['uids'] as List?)?.cast<String>() ?? const [];
        for (final u in uids) {
          if (u != myUid) ids.add(u);
        }
      }
      return ids;
    });
  }

  Future<void> acceptRequest(FriendRequest request, {
    required UserProfile me,
  }) async {
    if (request.toUid != me.uid) {
      throw StateError('Nur der Empfänger kann eine Anfrage annehmen.');
    }
    final key = friendshipPairKey(request.fromUid, request.toUid);
    final batch = _firestore.batch();
    batch.update(_requests.doc(request.id), {
      'status': statusToString(FriendRequestStatus.accepted),
      'respondedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    final ordered = [request.fromUid, request.toUid]..sort();
    batch.set(_friendships.doc(key), {
      'uids': ordered,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await batch.commit();
  }

  Future<void> declineRequest(FriendRequest request) async {
    await _requests.doc(request.id).update({
      'status': statusToString(FriendRequestStatus.declined),
      'respondedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> cancelRequest(FriendRequest request) async {
    await _requests.doc(request.id).update({
      'status': statusToString(FriendRequestStatus.cancelled),
      'respondedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeFriend(String myUid, String otherUid) async {
    final key = friendshipPairKey(myUid, otherUid);
    await _friendships.doc(key).delete();
  }
}
