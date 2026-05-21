import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import 'models/duel.dart';
import 'services/duel_service.dart';
import 'services/duel_set_builder.dart';

final duelSetBuilderProvider = Provider<DuelSetBuilder>((ref) {
  return DuelSetBuilder(ref.watch(databaseProvider));
});

final duelServiceProvider = Provider<DuelService>((ref) {
  return DuelService(ref.watch(firestoreProvider));
});

final incomingPendingDuelsProvider = StreamProvider<List<Duel>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(const []);
  return ref.watch(duelServiceProvider).watchIncomingPending(auth.uid);
});

final myPendingChallengesProvider = StreamProvider<List<Duel>>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(const []);
  return ref.watch(duelServiceProvider).watchMyPendingChallenges(auth.uid);
});

final duelByIdProvider =
    StreamProvider.family<Duel?, String>((ref, duelId) {
  return ref.watch(duelServiceProvider).watch(duelId);
});
