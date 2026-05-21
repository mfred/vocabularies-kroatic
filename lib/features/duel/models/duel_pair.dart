import '../../quiz/models/quiz_direction.dart';

/// Ein zu paarendes Vokabel-Pair. `leftText` ist die Prompt-Sprache, `rightText`
/// die Antwort-Sprache — abgeleitet aus [QuizDirection]. Während des Spiels
/// wird ein Draggable auf der linken Seite auf das passende DragTarget auf der
/// rechten Seite gezogen.
class DuelPair {
  const DuelPair({
    required this.itemId,
    required this.leftText,
    required this.rightText,
  });

  final String itemId;
  final String leftText;
  final String rightText;

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'left': leftText,
        'right': rightText,
      };

  factory DuelPair.fromMap(Map<String, dynamic> map) => DuelPair(
        itemId: map['itemId'] as String? ?? '',
        leftText: map['left'] as String? ?? '',
        rightText: map['right'] as String? ?? '',
      );
}

/// Eine Runde besteht aus 4–5 Paaren. `pairs` ist die natürliche Reihenfolge
/// (= linke Spalte). `rightOrder` ist die geshuffelte Anzeige-Reihenfolge der
/// rechten Spalte; enthält die gleichen `itemId`s wie `pairs`, nur permutiert.
class DuelRound {
  const DuelRound({required this.pairs, required this.rightOrder});

  final List<DuelPair> pairs;
  final List<String> rightOrder;

  /// Hilfsmethode: gibt die Paare in rechter Anzeige-Reihenfolge zurück.
  List<DuelPair> get rightPairs {
    final byId = {for (final p in pairs) p.itemId: p};
    return [for (final id in rightOrder) byId[id]!];
  }

  Map<String, dynamic> toMap() => {
        'pairs': [for (final p in pairs) p.toMap()],
        'rightOrder': rightOrder,
      };

  factory DuelRound.fromMap(Map<String, dynamic> map) => DuelRound(
        pairs: [
          for (final m in (map['pairs'] as List? ?? const []))
            DuelPair.fromMap(Map<String, dynamic>.from(m as Map)),
        ],
        rightOrder: (map['rightOrder'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}
