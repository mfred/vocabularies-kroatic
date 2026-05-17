enum QuizFormat {
  multipleChoice('mc', 'Auswählen'),
  type('type', 'Schreiben'),
  speak('speak', 'Sprechen'),
  listenSpeak('listen', 'Hören & Sprechen');

  const QuizFormat(this.code, this.label);

  final String code;
  final String label;

  static QuizFormat fromCode(String code) {
    for (final f in QuizFormat.values) {
      if (f.code == code) return f;
    }
    return QuizFormat.multipleChoice;
  }
}
