enum AnswerVerdict { strict, tolerant, wrong }

class AnswerEvaluation {
  const AnswerEvaluation({
    required this.verdict,
    required this.normalizedExpected,
    required this.normalizedUserInput,
  });

  final AnswerVerdict verdict;
  final String normalizedExpected;
  final String normalizedUserInput;

  bool get isCorrect => verdict != AnswerVerdict.wrong;
  bool get hasSpellingNotice => verdict == AnswerVerdict.tolerant;
}

class AnswerEvaluator {
  const AnswerEvaluator();

  /// Strict-equal: exakt gleich (nach NFC + Trim).
  /// Tolerant-equal: gleich nach Lowercase + Apostroph-Strip + Whitespace-Collapse.
  /// Diakritika (č, ć, š, ž, đ) bleiben relevant — sie werden NICHT normalisiert.
  AnswerEvaluation evaluate(String userInput, String expected) {
    final strictUser = _basicTrim(userInput);
    final strictExpected = _basicTrim(expected);
    if (strictUser.isNotEmpty && strictUser == strictExpected) {
      return AnswerEvaluation(
        verdict: AnswerVerdict.strict,
        normalizedExpected: strictExpected,
        normalizedUserInput: strictUser,
      );
    }
    final tolerantUser = _normalize(strictUser);
    final tolerantExpected = _normalize(strictExpected);
    if (tolerantUser.isNotEmpty && tolerantUser == tolerantExpected) {
      return AnswerEvaluation(
        verdict: AnswerVerdict.tolerant,
        normalizedExpected: strictExpected,
        normalizedUserInput: strictUser,
      );
    }
    return AnswerEvaluation(
      verdict: AnswerVerdict.wrong,
      normalizedExpected: strictExpected,
      normalizedUserInput: strictUser,
    );
  }

  static String _basicTrim(String s) {
    return s.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalize(String s) {
    var t = s.toLowerCase();
    // Verschiedene Apostroph-/Quote-Varianten entfernen
    t = t.replaceAll(RegExp(r"['ʼ‘’`´’ʼ]"), '');
    // Punctuation am Rand entfernen (.,?!:;)
    t = t.replaceAll(RegExp(r'^[\.\,\?\!\:\;]+|[\.\,\?\!\:\;]+$'), '');
    t = t.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }
}
