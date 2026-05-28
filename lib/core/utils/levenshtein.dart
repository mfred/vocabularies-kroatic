import 'dart:math';

/// Levenshtein-Editierdistanz zwischen zwei Strings (Anzahl Einfügungen,
/// Löschungen, Ersetzungen). Zwei-Zeilen-DP, O(a·b) Zeit, O(b) Speicher.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    curr[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      curr[j + 1] = min(
        min(curr[j] + 1, prev[j + 1] + 1),
        prev[j] + cost,
      );
    }
    for (var k = 0; k <= b.length; k++) {
      prev[k] = curr[k];
    }
  }
  return prev[b.length];
}
