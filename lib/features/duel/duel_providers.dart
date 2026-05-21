import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import 'services/duel_set_builder.dart';

final duelSetBuilderProvider = Provider<DuelSetBuilder>((ref) {
  return DuelSetBuilder(ref.watch(databaseProvider));
});
