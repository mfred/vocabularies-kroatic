import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../quiz/models/quiz_direction.dart';
import 'duel_providers.dart';
import 'screens/duel_play_screen.dart';
import 'services/duel_set_builder.dart';

/// Baut das Duell-Set für eine Lektion und startet den Play-Screen.
/// Zeigt eine SnackBar, wenn die Lektion zu wenige Vokabeln hat.
Future<void> startDuelForLesson(
  BuildContext context,
  WidgetRef ref,
  LessonsCacheData lesson,
  QuizDirection direction,
) async {
  final builder = ref.read(duelSetBuilderProvider);
  final rounds = await builder.build(
    lessonId: lesson.lessonId,
    direction: direction,
  );
  if (!context.mounted) return;
  if (rounds == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lektion hat zu wenige Vokabeln für ein Duell '
          '(mindestens $kDuelMinLessonItems benötigt).',
        ),
      ),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DuelPlayScreen(
        lessonTitle: lesson.titleDe,
        lessonId: lesson.lessonId,
        direction: direction,
        rounds: rounds,
      ),
    ),
  );
}
