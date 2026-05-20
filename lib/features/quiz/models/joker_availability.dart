import 'joker_type.dart';
import 'quiz_format.dart';
import 'quiz_question.dart';

bool jokerAvailable(
  JokerType joker, {
  required QuizQuestion question,
  required QuizFormat format,
}) {
  switch (joker) {
    case JokerType.ipa:
      final ipa = question.ipaHint;
      return ipa != null && ipa.isNotEmpty;
    case JokerType.fiftyFifty:
      return format == QuizFormat.multipleChoice &&
          question.options.length >= 4;
    case JokerType.picture:
      // Nur wenn für die Vokabel ein Icon-Mapping existiert; ohne Bild
      // wird der Joker nicht angeboten.
      return question.pictureIcon != null;
  }
}
