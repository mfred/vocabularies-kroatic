/// Spieler-Profil aus `users/{uid}` in Firestore. Denormalisierte Felder, damit
/// Suche (per Email / Anzeigename / Friend-Code) ohne Joins funktioniert.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.displayNameLower,
    required this.email,
    required this.friendCode,
    required this.createdAtMs,
  });

  final String uid;
  final String displayName;
  final String displayNameLower;
  final String email;
  final String friendCode;
  final int createdAtMs;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      displayNameLower: map['displayNameLower'] as String? ?? '',
      email: map['email'] as String? ?? '',
      friendCode: map['friendCode'] as String? ?? '',
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'displayNameLower': displayNameLower,
        'email': email,
        'friendCode': friendCode,
        'createdAtMs': createdAtMs,
      };
}
