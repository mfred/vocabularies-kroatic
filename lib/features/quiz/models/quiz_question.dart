import 'quiz_direction.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.itemId,
    required this.prompt,
    required this.correct,
    required this.options,
    required this.ipaHint,
    required this.isNewWord,
    required this.direction,
    required this.difficulty,
  });

  final String itemId;
  final String prompt;
  final String correct;
  final List<String> options;
  final String? ipaHint;
  final bool isNewWord;
  final QuizDirection direction;
  final int difficulty;
}
