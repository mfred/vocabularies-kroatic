import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import 'models/friend_request.dart';
import 'models/user_profile.dart';
import 'services/friend_service.dart';
import 'services/user_profile_service.dart';

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref.watch(firestoreProvider));
});

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(ref.watch(firestoreProvider));
});

/// Stream auf das eigene Profil. Null wenn nicht eingeloggt **oder** wenn
/// die Email noch nicht bestätigt ist (Double-Opt-In-Gate). Unverifizierte
/// Accounts haben kein Firestore-Profil und können dadurch nicht in der
/// Friend-Suche auftauchen oder Duelle starten.
final myUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null || !auth.emailVerified) return Stream.value(null);
  return ref.watch(userProfileServiceProvider).watch(auth.uid);
});

final incomingFriendRequestsProvider =
    StreamProvider<List<FriendRequest>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(const []);
  return ref.watch(friendServiceProvider).watchIncoming(auth.uid);
});

final outgoingFriendRequestsProvider =
    StreamProvider<List<FriendRequest>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(const []);
  return ref.watch(friendServiceProvider).watchOutgoing(auth.uid);
});

/// Eigene Freunde — als `UserProfile`-Liste, durch Auflösung der UIDs aus
/// `friendships`. Ändert sich live, wenn neue Freundschaften dazukommen.
///
/// Kein vorgezogenes `yield []`, weil das den UI-State zwischen "leer" und
/// "loading" flackern lässt, solange Firestore noch Verbindungsversuche
/// macht. Stream-Errors (z. B. Permission-Denied) kommen jetzt direkt als
/// AsyncError im UI an, statt unter einer fake-leeren Liste verborgen zu
/// bleiben.
final friendsListProvider = StreamProvider<List<UserProfile>>((ref) async* {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) {
    yield const [];
    return;
  }
  final service = ref.watch(friendServiceProvider);
  final profileService = ref.watch(userProfileServiceProvider);
  await for (final uids in service.watchFriendUids(auth.uid)) {
    if (uids.isEmpty) {
      yield const [];
      continue;
    }
    final profiles = await profileService.getManyByUids(uids);
    profiles.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    yield profiles;
  }
});

enum UserSearchKind { email, name }

/// Bulk-Lookup für mehrere `users/{uid}`-Profile auf einmal. Wird z. B. von
/// der Bestenliste verwendet, um pro Eintrag den individuellen `avatarStyle`
/// zu rendern, ohne N Einzel-Reads zu machen.
///
/// Family-Key ist die sortiert/komma-getrennte UID-Liste — Riverpod-Cache-
/// freundlich (gleiche Menge ⇒ gleicher Key ⇒ gleicher Provider-Zustand).
final profilesByUidsProvider = FutureProvider.autoDispose
    .family<Map<String, UserProfile>, String>((ref, uidsCsv) async {
  final uids = uidsCsv.split(',').where((s) => s.isNotEmpty).toList();
  if (uids.isEmpty) return const <String, UserProfile>{};
  final svc = ref.watch(userProfileServiceProvider);
  try {
    final profiles = await svc.getManyByUids(uids);
    return {for (final p in profiles) p.uid: p};
  } catch (_) {
    return const <String, UserProfile>{};
  }
});

/// Verwende [searchUsersProvider] über ein typisiertes Args-Objekt.
///
/// Beide Such-Pfade haben einen 8-Sekunden-Timeout — verhindert, dass der
/// UI-Spinner ewig dreht, wenn Firestore wegen Permission-Race oder
/// Netzwerk-Latenz nicht zeitnah antwortet.
final searchUsersProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, ({UserSearchKind kind, String query})>(
        (ref, args) async {
  final svc = ref.watch(userProfileServiceProvider);
  Future<List<UserProfile>> fut;
  switch (args.kind) {
    case UserSearchKind.email:
      fut = svc.searchByEmail(args.query);
      break;
    case UserSearchKind.name:
      fut = svc.searchByNamePrefix(args.query);
      break;
  }
  return fut.timeout(
    const Duration(seconds: 8),
    onTimeout: () => throw TimeoutException(
      'Suche dauerte zu lange. Bist du online?',
    ),
  );
});

/// Side-effect-Provider: sorgt dafür, dass `users/{uid}` bei jedem Login
/// existiert (idempotent). Wird in [app.dart] über `ref.watch` instanziiert.
/// **Wichtig**: legt das Profil nur an, wenn die Email bestätigt ist
/// (Double-Opt-In-Anforderung).
///
/// Initial-Sweep: zusätzlich zum `ref.listen` (das nur auf **künftige**
/// Auth-State-Änderungen reagiert) wird der **aktuelle** Auth-State direkt
/// beim Provider-Setup geprüft — sonst geht das Event verloren, wenn der
/// User die App schon im verifizierten Zustand öffnet.
final ensureProfileOnLoginProvider = Provider<void>((ref) {
  final svc = ref.watch(userProfileServiceProvider);
  final initial = ref.read(authStateProvider).value;
  if (initial != null && initial.emailVerified) {
    // Fire-and-forget; Fehler werden ignoriert, nächster Auth-Event retry.
    unawaited(() async {
      try {
        await svc.ensureProfile(initial);
      } catch (_) {}
    }());
  }
  ref.listen(authStateProvider, (prev, next) async {
    final user = next.value;
    if (user == null || !user.emailVerified) return;
    try {
      await svc.ensureProfile(user);
    } catch (_) {
      // Ignorieren — nicht blockierend; nächste App-Open ruft erneut auf.
    }
  });
});
