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

/// Stream auf das eigene Profil. Null wenn nicht eingeloggt.
final myUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(null);
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
    profiles.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    yield profiles;
  }
});

enum UserSearchKind { email, name, code }

/// Verwende [searchUsersProvider] über ein typisiertes Args-Objekt.
final searchUsersProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, ({UserSearchKind kind, String query})>(
        (ref, args) async {
  final svc = ref.watch(userProfileServiceProvider);
  switch (args.kind) {
    case UserSearchKind.email:
      return svc.searchByEmail(args.query);
    case UserSearchKind.name:
      return svc.searchByNamePrefix(args.query);
    case UserSearchKind.code:
      final p = await svc.searchByFriendCode(args.query);
      return p == null ? const [] : [p];
  }
});

/// Side-effect-Provider: sorgt dafür, dass `users/{uid}` bei jedem Login
/// existiert (idempotent). Wird in [app.dart] über `ref.listen` ausgelöst.
final ensureProfileOnLoginProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (prev, next) async {
    final user = next.value;
    if (user == null) return;
    try {
      await ref.read(userProfileServiceProvider).ensureProfile(user);
    } catch (_) {
      // Ignorieren — nicht blockierend; nächste App-Open ruft erneut auf.
    }
  });
});
