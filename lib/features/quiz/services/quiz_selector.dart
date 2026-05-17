import '../../../core/database/database.dart';
import '../models/item_attempt_stats.dart';

class QuizSelector {
  static const int newTarget = 6;
  static const int stumbledTarget = 3;
  static const int masteredTarget = 1;

  static List<Item> pick({
    required List<Item> items,
    required Map<String, ItemAttemptStats> stats,
    int count = 10,
  }) {
    if (items.isEmpty) return const [];

    final newItems = <Item>[];
    final stumbled = <Item>[];
    final mastered = <Item>[];

    for (final item in items) {
      final s = stats[item.id] ?? ItemAttemptStats.empty();
      if (s.isUnseen) {
        newItems.add(item);
      } else if (s.isStumbled) {
        stumbled.add(item);
      } else {
        mastered.add(item);
      }
    }

    int byLastSeenThenDifficulty(Item a, Item b) {
      final aMs = stats[a.id]?.lastAtMs;
      final bMs = stats[b.id]?.lastAtMs;
      if (aMs == null && bMs != null) return -1;
      if (aMs != null && bMs == null) return 1;
      if (aMs != null && bMs != null) {
        final byTime = aMs.compareTo(bMs);
        if (byTime != 0) return byTime;
      }
      final byDiff = a.difficulty.compareTo(b.difficulty);
      if (byDiff != 0) return byDiff;
      return a.id.compareTo(b.id);
    }

    newItems.sort(byLastSeenThenDifficulty);
    stumbled.sort(byLastSeenThenDifficulty);
    mastered.sort(byLastSeenThenDifficulty);

    final pool = <Item>[
      ...newItems.take(newTarget),
      ...stumbled.take(stumbledTarget),
      ...mastered.take(masteredTarget),
    ];
    final extras = <Item>[
      ...newItems.skip(newTarget),
      ...stumbled.skip(stumbledTarget),
      ...mastered.skip(masteredTarget),
    ];
    while (pool.length < count && extras.isNotEmpty) {
      pool.add(extras.removeAt(0));
    }
    final result = pool.take(count).toList();

    result.sort((a, b) {
      final byDiff = a.difficulty.compareTo(b.difficulty);
      if (byDiff != 0) return byDiff;
      return a.id.compareTo(b.id);
    });
    return result;
  }
}
