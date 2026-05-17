import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/services/answer_evaluator.dart';

void main() {
  group('AnswerEvaluator', () {
    const e = AnswerEvaluator();

    test('strict match returns strict verdict', () {
      final r = e.evaluate('Dobro jutro', 'Dobro jutro');
      expect(r.verdict, AnswerVerdict.strict);
      expect(r.isCorrect, isTrue);
      expect(r.hasSpellingNotice, isFalse);
    });

    test('case-insensitive match returns tolerant verdict', () {
      final r = e.evaluate('dobro jutro', 'Dobro jutro');
      expect(r.verdict, AnswerVerdict.tolerant);
      expect(r.isCorrect, isTrue);
      expect(r.hasSpellingNotice, isTrue);
      expect(r.normalizedExpected, 'Dobro jutro');
    });

    test('apostrophe is ignored', () {
      // Italienische/englische Apostroph-Varianten
      final r1 = e.evaluate("d'accordo", 'daccordo');
      expect(r1.verdict, AnswerVerdict.tolerant);
      final r2 = e.evaluate('d’accordo', 'daccordo');
      expect(r2.verdict, AnswerVerdict.tolerant);
    });

    test('extra whitespace is collapsed', () {
      final r = e.evaluate('  Dobro    jutro  ', 'Dobro jutro');
      expect(r.verdict, AnswerVerdict.strict);
    });

    test('trailing punctuation is ignored for tolerant match', () {
      final r = e.evaluate('Hvala!', 'Hvala');
      expect(r.verdict, AnswerVerdict.tolerant);
    });

    test('diacritics matter (different word = wrong)', () {
      final r = e.evaluate('Dovidenja', 'Doviđenja');
      expect(r.verdict, AnswerVerdict.wrong);
    });

    test('completely different words are wrong', () {
      final r = e.evaluate('Hallo', 'Bok');
      expect(r.verdict, AnswerVerdict.wrong);
      expect(r.isCorrect, isFalse);
    });

    test('empty input is wrong', () {
      final r = e.evaluate('', 'Bok');
      expect(r.verdict, AnswerVerdict.wrong);
    });
  });
}
