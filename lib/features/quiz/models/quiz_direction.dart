enum QuizDirection {
  deToHr('mc_de_hr', 'DE', 'HR', '🇩🇪 → 🇭🇷', '🇩🇪→🇭🇷'),
  hrToDe('mc_hr_de', 'HR', 'DE', '🇭🇷 → 🇩🇪', '🇭🇷→🇩🇪');

  const QuizDirection(
    this.mode,
    this.promptLang,
    this.answerLang,
    this.label,
    this.compactLabel,
  );

  final String mode;
  final String promptLang;
  final String answerLang;
  final String label;
  final String compactLabel;
}
