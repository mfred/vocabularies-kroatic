/// Ergebnis eines kompletten 3-Runden-Duell-Laufs. Zeiten in Millisekunden,
/// inklusive 200 ms Strafen pro falscher Zuordnung.
class DuelRunResult {
  const DuelRunResult({
    required this.roundsMs,
    required this.penaltiesMs,
  });

  /// Pro-Runden-Zeit (Stopwatch + Penalties). Genau drei Einträge.
  final List<int> roundsMs;

  /// Aufsummierte Strafe je Runde (jeweils ein Vielfaches von 200).
  final List<int> penaltiesMs;

  int get totalMs => roundsMs.fold(0, (a, b) => a + b);

  int get totalPenaltyMs => penaltiesMs.fold(0, (a, b) => a + b);
}
