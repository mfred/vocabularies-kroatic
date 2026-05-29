/// Formatiert eine Millisekunden-Dauer für die Duell-Screens:
/// `m:ss.cc` ab einer Minute, sonst `x.xx s`. Gemeinsame Quelle für Summary-
/// und Vergleichs-Screen (vorher in beiden byte-identisch dupliziert).
String formatDuelTime(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final centi = (ms % 1000) ~/ 10;
  if (minutes > 0) {
    return '$minutes:${seconds.toString().padLeft(2, '0')}.'
        '${centi.toString().padLeft(2, '0')}';
  }
  return '${(ms / 1000).toStringAsFixed(2)} s';
}
