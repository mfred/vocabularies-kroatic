/// Ergebnis eines kompletten 3-Runden-Duell-Laufs. Zeiten in Millisekunden,
/// inklusive Strafzeit pro falscher Zuordnung (siehe `kDuelPenaltyMs`).
class DuelRunResult {
  const DuelRunResult({
    required this.roundsMs,
    required this.penaltiesMs,
  });

  /// Pro-Runden-Zeit (Stopwatch + Penalties). Genau drei Einträge.
  final List<int> roundsMs;

  /// Aufsummierte Strafe je Runde (jeweils ein Vielfaches von `kDuelPenaltyMs`).
  final List<int> penaltiesMs;

  int get totalMs => roundsMs.fold(0, (a, b) => a + b);

  int get totalPenaltyMs => penaltiesMs.fold(0, (a, b) => a + b);
}
