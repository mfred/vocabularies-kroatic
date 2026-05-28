import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/utils/levenshtein.dart';

void main() {
  group('levenshtein', () {
    test('gleiche Strings → 0', () {
      expect(levenshtein('', ''), 0);
      expect(levenshtein('abc', 'abc'), 0);
    });

    test('leerer String → Länge des anderen', () {
      expect(levenshtein('', 'abc'), 3);
      expect(levenshtein('abc', ''), 3);
    });

    test('Ersetzung / Einfügung / Löschung je 1', () {
      expect(levenshtein('abc', 'abd'), 1);
      expect(levenshtein('ab', 'abc'), 1);
      expect(levenshtein('abc', 'ab'), 1);
    });

    test('klassisches Beispiel kitten → sitting = 3', () {
      expect(levenshtein('kitten', 'sitting'), 3);
    });

    test('Diakritika zählen als Unterschied', () {
      expect(levenshtein('cao', 'ćao'), 1);
    });
  });
}
