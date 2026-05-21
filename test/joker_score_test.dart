import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/controllers/quiz_session_controller.dart';
import 'package:vocabularies_kroatic/features/quiz/models/joker_availability.dart';
import 'package:vocabularies_kroatic/features/quiz/models/joker_type.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_format.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_question.dart';

QuizQuestion _question({
  String? ipa,
  int options = 4,
}) {
  return QuizQuestion(
    itemId: 'i1',
    prompt: 'Hallo',
    correct: 'Bok',
    options: List.generate(options, (i) => i == 0 ? 'Bok' : 'opt_$i'),
    ipaHint: ipa,
    isNewWord: true,
    direction: QuizDirection.deToHr,
    difficulty: 1,
  );
}

void main() {
  group('computeScore (Skala x20)', () {
    test('no jokers, perfect run', () {
      // 10×5 + (30 − 60/20) − 0 = 50 + 27 = 77
      expect(
        computeScore(
            correctCount: 10, durationSeconds: 60, jokerCost: 0),
        77,
      );
    });

    test('ipa joker x2 = -4', () {
      // 10×5 + 30 − (2×2) = 76
      expect(
        computeScore(
            correctCount: 10, durationSeconds: 0, jokerCost: 4),
        76,
      );
    });

    test('mixed jokers add to total cost', () {
      // 2× ipa (2) + 1× 50/50 (1) + 1× audio (1) = 6
      // 10×5 + 30 − 6 = 74
      expect(
        computeScore(
            correctCount: 10, durationSeconds: 0, jokerCost: 6),
        74,
      );
    });

    test('floor at 0', () {
      expect(
        computeScore(
            correctCount: 0, durationSeconds: 1000, jokerCost: 100),
        0,
      );
    });
  });

  group('jokerAvailable', () {
    test('ipa available when ipaHint present', () {
      final q = _question(ipa: '[bok]');
      expect(
        jokerAvailable(JokerType.ipa,
            question: q, format: QuizFormat.multipleChoice),
        isTrue,
      );
    });

    test('ipa not available when ipaHint missing', () {
      final q = _question();
      expect(
        jokerAvailable(JokerType.ipa,
            question: q, format: QuizFormat.multipleChoice),
        isFalse,
      );
    });

    test('50/50 only in multipleChoice', () {
      final q = _question();
      expect(
        jokerAvailable(JokerType.fiftyFifty,
            question: q, format: QuizFormat.multipleChoice),
        isTrue,
      );
      expect(
        jokerAvailable(JokerType.fiftyFifty,
            question: q, format: QuizFormat.type),
        isFalse,
      );
      expect(
        jokerAvailable(JokerType.fiftyFifty,
            question: q, format: QuizFormat.speak),
        isFalse,
      );
    });

    test('audio joker ist unabhängig vom Format immer verfügbar', () {
      final q = _question();
      for (final f in QuizFormat.values) {
        expect(
          jokerAvailable(JokerType.audio, question: q, format: f),
          isTrue,
          reason: 'audio sollte auch in $f verfügbar sein',
        );
      }
    });
  });
}
