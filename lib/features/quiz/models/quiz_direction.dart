enum QuizDirection {
  deToHr('de_hr', 'DE', 'HR', 'de-DE', 'hr-HR', '🇩🇪 → 🇭🇷', '🇩🇪→🇭🇷'),
  hrToDe('hr_de', 'HR', 'DE', 'hr-HR', 'de-DE', '🇭🇷 → 🇩🇪', '🇭🇷→🇩🇪');

  const QuizDirection(
    this.code,
    this.promptLang,
    this.answerLang,
    this.promptLangTag,
    this.answerLangTag,
    this.label,
    this.compactLabel,
  );

  /// Direction-only code used as a DB key (e.g. `de_hr`). Wird in den
  /// stats-/seen-Queries gegen `quiz_sessions.direction` gematcht.
  final String code;

  /// Backward-compat: alte Aufrufer erwarteten ein `mode`-Feld. Liefert
  /// jetzt einfach den `code` — die DB filtert auf direction.
  String get mode => code;

  final String promptLang;
  final String answerLang;
  final String promptLangTag;
  final String answerLangTag;
  final String label;
  final String compactLabel;
}
