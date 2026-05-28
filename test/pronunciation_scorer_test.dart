import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/services/answer_evaluator.dart';

void main() {
  group('AnswerEvaluator.pronunciationScore', () {
    test('exakt → 1.0, inkl. Groß-/Klein­schreibung und Randpunktuation', () {
      expect(AnswerEvaluator.pronunciationScore('Bok', 'Bok'), 1.0);
      expect(AnswerEvaluator.pronunciationScore('bok.', 'Bok'), 1.0);
    });

    test('Diakritika werden gefaltet → fehlender Akzent senkt Score nicht', () {
      // 'cao' vs 'ćao': ć→c-Faltung in der Normalisierung → identisch.
      expect(AnswerEvaluator.pronunciationScore('cao', 'ćao'), 1.0);
    });

    test('völlig anderes Wort → niedriger Score', () {
      expect(
        AnswerEvaluator.pronunciationScore('auto', 'hvala'),
        lessThan(0.5),
      );
    });
  });

  group('AnswerEvaluator.evaluate (fuzzy / Sprechen)', () {
    const e = AnswerEvaluator();

    test('exakt gesprochen → strict, richtig, Score 1.0', () {
      final r = e.evaluate('Hvala', 'Hvala', fuzzy: true);
      expect(r.verdict, AnswerVerdict.strict);
      expect(r.isCorrect, isTrue);
      expect(r.score, 1.0);
    });

    test('knapp daneben oberhalb der Schwelle → close, richtig', () {
      // 'hfala' vs 'hvala': 1 Ersetzung bei Länge 5 → Score 0.8 ≥ 0.6.
      final r = e.evaluate('hfala', 'hvala', fuzzy: true);
      expect(r.verdict, AnswerVerdict.close);
      expect(r.isCorrect, isTrue);
      expect(r.score, closeTo(0.8, 1e-9));
    });

    test('weit daneben → wrong, aber Score gesetzt', () {
      final r = e.evaluate('auto', 'hvala', fuzzy: true);
      expect(r.verdict, AnswerVerdict.wrong);
      expect(r.isCorrect, isFalse);
      expect(r.score, isNotNull);
      expect(r.score, lessThan(AnswerEvaluator.kPronunciationPassThreshold));
    });

    test('ohne fuzzy (z.B. Multiple Choice) bleibt knapper Treffer wrong, Score null', () {
      final r = e.evaluate('hfala', 'hvala');
      expect(r.verdict, AnswerVerdict.wrong);
      expect(r.score, isNull);
    });
  });
}
