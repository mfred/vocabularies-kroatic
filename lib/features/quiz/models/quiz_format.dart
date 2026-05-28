enum QuizFormat {
  multipleChoice('mc', 'Vokabelcheck'),
  type('type', 'Schreiben'),
  speak('speak', 'Sprechen'),
  listenSpeak('listen', 'Hören & Sprechen');

  const QuizFormat(this.code, this.label);

  final String code;
  final String label;

  /// Sprech-Formate werten die Eingabe per Aussprache-Score (Levenshtein) aus,
  /// nicht nur exakt/tolerant.
  bool get isSpeech =>
      this == QuizFormat.speak || this == QuizFormat.listenSpeak;

  static QuizFormat fromCode(String code) {
    for (final f in QuizFormat.values) {
      if (f.code == code) return f;
    }
    return QuizFormat.multipleChoice;
  }
}
