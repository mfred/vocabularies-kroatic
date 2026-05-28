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
      return ipa != null && ipa.trim().isNotEmpty;
    case JokerType.fiftyFifty:
      return format == QuizFormat.multipleChoice &&
          question.options.length >= 4;
    case JokerType.audio:
      // Vorlesen ist immer verfügbar — fehlt die TTS-Sprache, gibt der
      // TtsService still nichts aus.
      return true;
  }
}
