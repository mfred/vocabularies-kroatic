import 'sm2_scheduler.dart';

/// Reife-Stufe einer Lernkarte (Vokabel × Richtung), abgeleitet aus ihrem
/// gefalteten SM-2-Zustand. Bewusst Anki-nah: ab [kMatureIntervalDays] Tagen
/// Intervall gilt eine Karte als „reif".
enum VocabMaturityBucket { learning, young, mature }

/// Intervall-Schwelle (Tage), ab der eine Karte als „reif" zählt.
const int kMatureIntervalDays = 21;

/// Intervall-Schwelle (Tage), ab der eine Karte als „jung" (statt „am Lernen")
/// zählt. Entspricht der zweiten SM-2-Stufe (Intervalle laufen 1 → 6 → …).
const int kYoungIntervalDays = 6;

/// Ordnet einen SM-2-Zustand rein über das Intervall einer Reife-Stufe zu
/// (die SM-2-Intervalle laufen 1 → 6 → ~16 → ~40 …):
/// - **reif**: Intervall ≥ [kMatureIntervalDays] (≈ 4× sicher gewusst).
/// - **jung**: Intervall ≥ [kYoungIntervalDays] (mehrfach gewusst, festigt sich).
/// - **am Lernen**: Intervall < [kYoungIntervalDays] — frisch gesehen, erst
///   einmal gewusst, oder nach einem Fehler zurückgesetzt (Scheduler → 1 Tag).
VocabMaturityBucket maturityBucketOf(Sm2State s) {
  if (s.intervalDays >= kMatureIntervalDays) return VocabMaturityBucket.mature;
  if (s.intervalDays >= kYoungIntervalDays) return VocabMaturityBucket.young;
  return VocabMaturityBucket.learning;
}

/// Verteilung der geübten Karten über die drei Reife-Stufen. „Karten" zählen je
/// Vokabel UND Richtung (de→hr und hr→de getrennt). Nur tatsächlich geübte
/// Karten sind enthalten — der SM-2-Zustand wird aus der `quiz_attempts`-
/// Historie gefaltet, ungesehene Vokabeln tauchen also gar nicht erst auf.
class VocabMaturity {
  const VocabMaturity({
    required this.learning,
    required this.young,
    required this.mature,
  });

  final int learning;
  final int young;
  final int mature;

  int get total => learning + young + mature;
  bool get isEmpty => total == 0;
}

/// Faltet eine Menge SM-2-Zustände zu einer [VocabMaturity]-Verteilung.
VocabMaturity buildVocabMaturity(Iterable<Sm2State> states) {
  var learning = 0;
  var young = 0;
  var mature = 0;
  for (final s in states) {
    final bucket = maturityBucketOf(s);
    if (bucket == VocabMaturityBucket.mature) {
      mature++;
    } else if (bucket == VocabMaturityBucket.young) {
      young++;
    } else {
      learning++;
    }
  }
  return VocabMaturity(learning: learning, young: young, mature: mature);
}
