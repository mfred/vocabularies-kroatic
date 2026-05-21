import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/services/quiz_builder.dart';

Item _item(String id, String stage) => Item(
      id: id,
      lessonId: 'lesson_x',
      type: stage == 'words'
          ? 'word'
          : (stage == 'phrases' ? 'phrase' : 'sentence'),
      stage: stage,
      difficulty: 1,
      deText: 'de_$id',
      hrText: 'hr_$id',
      lessonVersion: '1.0.0',
    );

void main() {
  group('sortByStage', () {
    test('Wörter kommen vor Phrasen, Phrasen vor Sätzen', () {
      final mixed = [
        _item('s1', 'sentences'),
        _item('p1', 'phrases'),
        _item('w1', 'words'),
        _item('s2', 'sentences'),
        _item('w2', 'words'),
      ];
      final sorted = sortByStage(mixed);
      expect(sorted.map((e) => e.stage).toList(), [
        'words',
        'words',
        'phrases',
        'sentences',
        'sentences',
      ]);
    });

    test('Reihenfolge innerhalb derselben Stage bleibt stabil', () {
      // Eingangsordnung: w_b kommt vor w_a — der Sort darf nicht
      // alphabetisch auf id sortieren.
      final input = [
        _item('w_b', 'words'),
        _item('w_a', 'words'),
        _item('p_b', 'phrases'),
        _item('p_a', 'phrases'),
      ];
      final sorted = sortByStage(input);
      expect(sorted.map((e) => e.id).toList(),
          ['w_b', 'w_a', 'p_b', 'p_a']);
    });

    test('Unbekannte Stage landet hinten', () {
      final input = [
        _item('x1', 'mystery'),
        _item('w1', 'words'),
        _item('p1', 'phrases'),
      ];
      final sorted = sortByStage(input);
      expect(sorted.map((e) => e.stage).toList(),
          ['words', 'phrases', 'mystery']);
    });
  });
}
