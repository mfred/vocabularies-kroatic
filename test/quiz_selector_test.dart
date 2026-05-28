import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/core/database/database.dart';
import 'package:vocabularies_kroatic/features/quiz/services/quiz_selector.dart';
import 'package:vocabularies_kroatic/features/quiz/services/sm2_scheduler.dart';

const int _day = 86400000;

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

Sm2State _state({required int dueAtMs}) => Sm2State(
      easeFactor: 2.5,
      repetitions: 1,
      intervalDays: 1,
      dueAtMs: dueAtMs,
      lastReviewedMs: 0,
    );

void main() {
  group('QuizSelector (SM-2)', () {
    const now = 100 * _day;

    test('erstes Spiel ohne SM-2-Stand: 10 leichteste, nach difficulty/id', () {
      final items = [
        for (var i = 0; i < 20; i++)
          _item('w_${i.toString().padLeft(2, '0')}', difficulty: 1 + (i % 5)),
      ];
      final picked =
          QuizSelector.pick(items: items, sm2: const {}, asOfMs: now);
      expect(picked.length, 10);
      for (var i = 0; i < picked.length - 1; i++) {
        expect(picked[i].difficulty <= picked[i + 1].difficulty, isTrue,
            reason: 'Difficulty muss aufsteigend sein');
      }
    });

    test('fällige Items werden vor nicht-fälligen gewählt', () {
      final due = _item('due_01');
      final notDue = _item('notdue_01');
      final picked = QuizSelector.pick(
        items: [notDue, due],
        sm2: {
          'due_01': _state(dueAtMs: now - _day), // überfällig
          'notdue_01': _state(dueAtMs: now + 5 * _day), // erst später fällig
        },
        asOfMs: now,
        count: 1,
      );
      expect(picked.map((e) => e.id), ['due_01']);
    });

    test('bei Überzahl fälliger Items kommen die überfälligsten rein', () {
      // 15 fällige Items mit dueAt 0..14 (alle <= now). count=10 → die 10
      // überfälligsten (dueAt 0..9) müssen rein, 10..14 fallen raus.
      final items = [for (var i = 0; i < 15; i++) _item('i_$i')];
      final sm2 = {
        for (var i = 0; i < 15; i++) 'i_$i': _state(dueAtMs: i),
      };
      final picked = QuizSelector.pick(items: items, sm2: sm2, asOfMs: now);
      final ids = picked.map((e) => e.id).toSet();
      expect(picked.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(ids.contains('i_$i'), isTrue, reason: 'i_$i (überfällig) fehlt');
      }
      for (var i = 10; i < 15; i++) {
        expect(ids.contains('i_$i'), isFalse,
            reason: 'i_$i (am wenigsten überfällig) sollte raus sein');
      }
    });

    test('neue Items kommen mit dazu (newTarget)', () {
      final dueItems = [for (var i = 0; i < 6; i++) _item('due_$i')];
      final newItems = [for (var i = 0; i < 5; i++) _item('new_$i')];
      final sm2 = {
        for (var i = 0; i < 6; i++) 'due_$i': _state(dueAtMs: now - _day),
      };
      final picked = QuizSelector.pick(
        items: [...dueItems, ...newItems],
        sm2: sm2,
        asOfMs: now,
      );
      final newPicked =
          picked.where((e) => e.id.startsWith('new_')).length;
      expect(newPicked, greaterThanOrEqualTo(QuizSelector.newTarget));
    });

    test('Pool kleiner als count → liefert was da ist', () {
      final picked = QuizSelector.pick(
        items: [_item('only_a')],
        sm2: const {},
        asOfMs: now,
      );
      expect(picked.length, 1);
    });
  });
}
