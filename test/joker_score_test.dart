import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/controllers/quiz_session_controller.dart';
import 'package:vocabularies_kroatic/features/quiz/models/joker_availability.dart';
import 'package:vocabularies_kroatic/features/quiz/models/joker_type.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_format.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_question.dart';

QuizQuestion _question({
  String? ipa,
  IconData? icon,
  int options = 4,
}) {
  return QuizQuestion(
    itemId: 'i1',
    prompt: 'Hallo',
    correct: 'Bok',
    options: List.generate(options, (i) => i == 0 ? 'Bok' : 'opt_$i'),
    ipaHint: ipa,
    pictureIcon: icon,
    isNewWord: true,
    direction: QuizDirection.deToHr,
    difficulty: 1,
  );
}

void main() {
  group('computeScore (joker costs)', () {
    test('no jokers, perfect run', () {
      expect(
        computeScore(
            correctCount: 10, durationSeconds: 60, jokerCost: 0),
        1540,
      );
    });

    test('ipa joker x2 = -10', () {
      expect(
        computeScore(
            correctCount: 10, durationSeconds: 0, jokerCost: 10),
        1590,
      );
    });

    test('mixed jokers add to total cost', () {
      // 2x ipa (5) + 1x 50/50 (15) + 1x picture (5) = 35
      expect(
        computeScore(
            correctCount: 10, durationSeconds: 0, jokerCost: 35),
        1565,
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

    test('picture available when pictureIcon present', () {
      final q = _question(icon: Icons.book);
      expect(
        jokerAvailable(JokerType.picture,
            question: q, format: QuizFormat.multipleChoice),
        isTrue,
      );
    });

    test('picture not available without icon', () {
      final q = _question();
      expect(
        jokerAvailable(JokerType.picture,
            question: q, format: QuizFormat.multipleChoice),
        isFalse,
      );
    });
  });
}
