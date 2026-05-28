import 'dart:math';

import '../../../core/utils/levenshtein.dart';

enum AnswerVerdict { strict, tolerant, close, wrong }

class AnswerEvaluation {
  const AnswerEvaluation({
    required this.verdict,
    required this.normalizedExpected,
    required this.normalizedUserInput,
    this.score,
  });

  final AnswerVerdict verdict;
  final String normalizedExpected;
  final String normalizedUserInput;

  /// Ausspracheähnlichkeit [0.0, 1.0] — nur bei fuzzy-Auswertung (Sprechen)
  /// gesetzt, sonst null. 1.0 bei exakter/toleranter Übereinstimmung.
  final double? score;

  bool get isCorrect => verdict != AnswerVerdict.wrong;

  /// Schreibweise-Hinweis nur bei tolerantem Tipp-Treffer (Groß-/Klein­schreibung,
  /// Apostroph etc.) — beim Sprechen übernimmt die Aussprache-Prozentzahl.
  bool get hasSpellingNotice => verdict == AnswerVerdict.tolerant;
}

class AnswerEvaluator {
  const AnswerEvaluator();

  /// Ab dieser Ausspracheähnlichkeit gilt eine gesprochene Antwort als richtig.
  /// 0.6 entspricht der „ok"-Pass-Grenze in PROJECT.md §7.3 — bewusst nachsichtig,
  /// um das Sprechen zu fördern. Leicht justierbar.
  static const double kPronunciationPassThreshold = 0.6;

  /// Strict-equal: exakt gleich (nach NFC + Trim) — die perfekte Antwort, kein Hinweis.
  /// Tolerant-equal (nur wenn [tolerant]): gleich nach Lowercase + Apostroph-Strip +
  /// Diakritika-Faltung (č/ć→c, š→s, ž→z, đ→d) + Whitespace-Collapse. Eine nur durch
  /// Akzente abweichende Antwort gilt damit als richtig — mit Schreibweise-Hinweis.
  /// Bei [fuzzy] (Sprechen) wird zusätzlich eine Levenshtein-Ähnlichkeit berechnet:
  /// ab [kPronunciationPassThreshold] zählt die Antwort als `close` (richtig).
  ///
  /// [tolerant] ist für Multiple Choice auszuschalten (exakte Option-Auswahl) — sonst
  /// könnte eine nur-diakritisch abweichende falsche Option als richtig durchgehen.
  AnswerEvaluation evaluate(
    String userInput,
    String expected, {
    bool tolerant = true,
    bool fuzzy = false,
  }) {
    final strictUser = _basicTrim(userInput);
    final strictExpected = _basicTrim(expected);
    if (strictUser.isNotEmpty && strictUser == strictExpected) {
      return AnswerEvaluation(
        verdict: AnswerVerdict.strict,
        normalizedExpected: strictExpected,
        normalizedUserInput: strictUser,
        score: fuzzy ? 1.0 : null,
      );
    }
    final tolerantUser = _normalize(strictUser);
    final tolerantExpected = _normalize(strictExpected);
    if (tolerant &&
        tolerantUser.isNotEmpty &&
        tolerantUser == tolerantExpected) {
      return AnswerEvaluation(
        verdict: AnswerVerdict.tolerant,
        normalizedExpected: strictExpected,
        normalizedUserInput: strictUser,
        score: fuzzy ? 1.0 : null,
      );
    }
    if (fuzzy) {
      final sim = _similarity(tolerantUser, tolerantExpected);
      return AnswerEvaluation(
        verdict: sim >= kPronunciationPassThreshold
            ? AnswerVerdict.close
            : AnswerVerdict.wrong,
        normalizedExpected: strictExpected,
        normalizedUserInput: strictUser,
        score: sim,
      );
    }
    return AnswerEvaluation(
      verdict: AnswerVerdict.wrong,
      normalizedExpected: strictExpected,
      normalizedUserInput: strictUser,
    );
  }

  /// Ausspracheähnlichkeit [0.0, 1.0] nach PROJECT.md §8.3: normalisierte
  /// Levenshtein-Distanz. Öffentlich für Tests und Wiederverwendung.
  static double pronunciationScore(String spoken, String target) =>
      _similarity(
        _normalize(_basicTrim(spoken)),
        _normalize(_basicTrim(target)),
      );

  static double _similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 0.0;
    return 1.0 - levenshtein(a, b) / maxLen;
  }

  static String _basicTrim(String s) {
    return s.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalize(String s) {
    var t = s.toLowerCase();
    // Verschiedene Apostroph-/Quote-Varianten entfernen
    t = t.replaceAll(RegExp(r"['ʼ‘’`´’ʼ]"), '');
    // Kroatische Diakritika falten, damit eine nur durch Akzente abweichende
    // Antwort als tolerant-richtig gilt (mit Hinweis statt als Fehler).
    t = _foldDiacritics(t);
    // Punctuation am Rand entfernen (.,?!:;)
    t = t.replaceAll(RegExp(r'^[\.\,\?\!\:\;]+|[\.\,\?\!\:\;]+$'), '');
    t = t.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  static const Map<String, String> _diacriticFolds = {
    'č': 'c',
    'ć': 'c',
    'š': 's',
    'ž': 'z',
    'đ': 'd',
  };

  static String _foldDiacritics(String s) {
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      buf.write(_diacriticFolds[ch] ?? ch);
    }
    return buf.toString();
  }
}
