import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class UserProfileService {
  UserProfileService(this._firestore);

  final FirebaseFirestore _firestore;
  final Random _rng = Random.secure();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Stellt sicher, dass `users/{uid}` existiert und synchron zum aktuellen
  /// FirebaseAuth-User ist (displayName + email werden gespiegelt). Wird bei
  /// jedem Login/Signup über einen Listener auf authStateChanges aufgerufen.
  Future<UserProfile> ensureProfile(User user) async {
    final doc = _users.doc(user.uid);
    final snap = await doc.get();
    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (user.email ?? 'Spieler').split('@').first;
    final email = user.email ?? '';

    if (!snap.exists) {
      final friendCode = await _generateUniqueFriendCode();
      final profile = UserProfile(
        uid: user.uid,
        displayName: displayName,
        displayNameLower: displayName.toLowerCase(),
        email: email,
        friendCode: friendCode,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await doc.set(profile.toMap());
      return profile;
    }

    final existing = UserProfile.fromMap(user.uid, snap.data() ?? {});
    final needsUpdate = existing.displayName != displayName ||
        existing.email != email ||
        existing.displayNameLower != displayName.toLowerCase();
    if (needsUpdate) {
      await doc.update({
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
        'email': email,
      });
      return UserProfile(
        uid: user.uid,
        displayName: displayName,
        displayNameLower: displayName.toLowerCase(),
        email: email,
        friendCode: existing.friendCode,
        createdAtMs: existing.createdAtMs,
      );
    }
    return existing;
  }

  Stream<UserProfile?> watch(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(uid, snap.data() ?? {});
    });
  }

  Future<UserProfile?> getByUid(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(uid, snap.data() ?? {});
  }

  Future<List<UserProfile>> getManyByUids(Iterable<String> uids) async {
    final unique = uids.toSet().toList();
    if (unique.isEmpty) return const [];
    final results = <UserProfile>[];
    // Firestore whereIn ist auf 30 Werte begrenzt — in Tranchen.
    for (var i = 0; i < unique.length; i += 30) {
      final batch = unique.sublist(i, (i + 30).clamp(0, unique.length));
      final snap = await _users
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        results.add(UserProfile.fromMap(doc.id, doc.data()));
      }
    }
    return results;
  }

  Future<List<UserProfile>> searchByEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return const [];
    final snap = await _users
        .where('email', isEqualTo: trimmed.toLowerCase())
        .limit(5)
        .get();
    return [
      for (final d in snap.docs) UserProfile.fromMap(d.id, d.data()),
    ];
  }

  Future<List<UserProfile>> searchByNamePrefix(String prefix) async {
    final lower = prefix.trim().toLowerCase();
    if (lower.length < 3) return const [];
    final snap = await _users
        .where('displayNameLower', isGreaterThanOrEqualTo: lower)
        .where('displayNameLower', isLessThan: '$lower')
        .limit(10)
        .get();
    return [
      for (final d in snap.docs) UserProfile.fromMap(d.id, d.data()),
    ];
  }

  Future<UserProfile?> searchByFriendCode(String code) async {
    final upper = code.trim().toUpperCase();
    if (upper.length != 6) return null;
    final snap = await _users
        .where('friendCode', isEqualTo: upper)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserProfile.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<String> _generateUniqueFriendCode() async {
    // Bei < 1k Nutzern ist Kollision sehr unwahrscheinlich; wir prüfen
    // dennoch und versuchen ggf. erneut.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final existing = await searchByFriendCode(code);
      if (existing == null) return code;
    }
    // Fallback: längerer Code falls 5 Kollisionen hintereinander.
    return _randomCode(length: 8);
  }

  String _randomCode({int length = 6}) {
    // Ohne 0/O/1/I/L/U für gute Lesbarkeit.
    const chars = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[_rng.nextInt(chars.length)]);
    }
    return buf.toString();
  }
}
