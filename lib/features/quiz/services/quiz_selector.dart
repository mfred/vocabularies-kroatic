import '../../../core/database/database.dart';
import 'sm2_scheduler.dart';

/// Wählt die Quiz-Fragen einer Lektion nach SM-2: bevorzugt fällige
/// Wiederholungen (am überfälligsten zuerst), mischt ein paar neue Items dazu
/// und füllt mit den als Nächstes fälligen auf. Der SM-2-Zustand wird aus der
/// Antwort-Historie gefaltet (siehe [AppDatabase.sm2StatesByItem]).
class QuizSelector {
  /// Wie viele fällige bzw. neue Items bevorzugt in den Pool kommen, bevor
  /// mit den restlichen (am ehesten wieder fälligen) aufgefüllt wird.
  static const int dueTarget = 6;
  static const int newTarget = 3;

  static List<Item> pick({
    required List<Item> items,
    required Map<String, Sm2State> sm2,
    required int asOfMs,
    int count = 10,
  }) {
    if (items.isEmpty) return const [];

    final due = <Item>[];
    final unseen = <Item>[];
    final notDue = <Item>[];
    for (final item in items) {
      final s = sm2[item.id];
      if (s == null) {
        unseen.add(item);
      } else if (s.dueAtMs <= asOfMs) {
        due.add(item);
      } else {
        notDue.add(item);
      }
    }

    int byDifficulty(Item a, Item b) {
      final d = a.difficulty.compareTo(b.difficulty);
      return d != 0 ? d : a.id.compareTo(b.id);
    }

    int byDue(Item a, Item b) =>
        sm2[a.id]!.dueAtMs.compareTo(sm2[b.id]!.dueAtMs);

    due.sort(byDue); // überfälligste zuerst
    unseen.sort(byDifficulty); // sanfter Einstieg: leichteste zuerst
    notDue.sort(byDue); // am ehesten wieder fällig zuerst

    final pool = <Item>[
      ...due.take(dueTarget),
      ...unseen.take(newTarget),
    ];
    final extras = <Item>[
      ...due.skip(dueTarget),
      ...unseen.skip(newTarget),
      ...notDue,
    ];
    var i = 0;
    while (pool.length < count && i < extras.length) {
      pool.add(extras[i++]);
    }
    // Stabile Endsortierung nach difficulty/id (die Anzeige-Reihenfolge legt
    // anschließend der QuizBuilder per sortByStage fest).
    return pool.take(count).toList()..sort(byDifficulty);
  }
}
