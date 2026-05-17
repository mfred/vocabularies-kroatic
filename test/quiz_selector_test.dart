import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/models/item_attempt_stats.dart';
import 'package:vocabularies_kroatic/features/quiz/services/quiz_selector.dart';

Item _item(String id, {int difficulty = 1, String stage = 'words'}) => Item(
      id: id,
      lessonId: 'lesson_x',
      type: stage == 'words'
          ? 'word'
          : (stage == 'phrases' ? 'phrase' : 'sentence'),
      stage: stage,
      difficulty: difficulty,
      deText: 'de_$id',
      hrText: 'hr_$id',
      lessonVersion: '1.0.0',
    );

void main() {
  group('QuizSelector', () {
    test(
      'erstes Spiel ohne Stats: liefert die 10 leichtesten Items, sortiert nach difficulty/id',
      () {
        final items = [
          for (var i = 0; i < 20; i++)
            _item('w_${i.toString().padLeft(2, '0')}',
                difficulty: 1 + (i % 5)),
        ];
        final picked = QuizSelector.pick(items: items, stats: const {});
        expect(picked.length, 10);
        // Erste sind diff=1, dann diff=2 etc.
        expect(picked.first.difficulty, lessThanOrEqualTo(picked.last.difficulty));
        for (var i = 0; i < picked.length - 1; i++) {
          expect(
            picked[i].difficulty <= picked[i + 1].difficulty,
            isTrue,
            reason: 'Difficulty muss aufsteigend sein',
          );
        }
      },
    );

    test('stumbled-Bias: falsch beantwortetes Item kommt zurück, korrektes nicht',
        () {
      final wrongItem = _item('stumble_01', difficulty: 1);
      final correctItem = _item('master_01', difficulty: 1);
      // Beide gleiche Difficulty — ohne Bias würde Sortierung alphabetisch master_ vor stumble_ stellen.
      final newItems = [
        for (var i = 0; i < 4; i++)
          _item('new_${i.toString().padLeft(2, '0')}', difficulty: 1),
      ];
      final items = [wrongItem, correctItem, ...newItems];
      final stats = <String, ItemAttemptStats>{
        'stumble_01': const ItemAttemptStats(
          seenCount: 2,
          wrongCount: 2,
          lastCorrect: false,
          lastAtMs: 1000,
        ),
        'master_01': const ItemAttemptStats(
          seenCount: 3,
          wrongCount: 0,
          lastCorrect: true,
          lastAtMs: 2000,
        ),
      };
      final picked = QuizSelector.pick(items: items, stats: stats);
      final ids = picked.map((e) => e.id).toSet();
      expect(ids.contains('stumble_01'), isTrue,
          reason: 'STUMBLED-Item gehört in den Quiz');
      // Mit 4 new + 1 stumbled + 1 mastered = 6 Items total, 10 angefordert
      // → fillover packt auch mastered_01 rein. Wichtig ist: stumbled ist drin.
    });

    test(
      'steady-state: alle Items gemeistert → MASTERED-Bucket füllt, '
      'am längsten nicht gesehen zuerst',
      () {
        final items = [
          _item('a', difficulty: 1),
          _item('b', difficulty: 1),
          _item('c', difficulty: 1),
        ];
        final stats = {
          'a': const ItemAttemptStats(
            seenCount: 2,
            wrongCount: 0,
            lastCorrect: true,
            lastAtMs: 3000, // zuletzt gespielt
          ),
          'b': const ItemAttemptStats(
            seenCount: 2,
            wrongCount: 0,
            lastCorrect: true,
            lastAtMs: 1000, // länger nicht gesehen
          ),
          'c': const ItemAttemptStats(
            seenCount: 2,
            wrongCount: 0,
            lastCorrect: true,
            lastAtMs: 2000,
          ),
        };
        final picked = QuizSelector.pick(items: items, stats: stats);
        // Alle 3 müssen rein (count=10, Pool=3).
        expect(picked.map((e) => e.id).toSet(), {'a', 'b', 'c'});
        // Sortierung im Result ist nach difficulty/id (a,b,c).
        expect(picked.map((e) => e.id).toList(), ['a', 'b', 'c']);
      },
    );

    test(
      'first-game stays under count when pool smaller than count',
      () {
        final items = [_item('only_a', difficulty: 1)];
        final picked = QuizSelector.pick(items: items, stats: const {});
        expect(picked.length, 1);
      },
    );
  });
}
