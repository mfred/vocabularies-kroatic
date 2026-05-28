import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/screens/quiz_summary_screen.dart';

void main() {
  testWidgets(
      'QuizSummaryScreen im Querformat: kein Overflow, alle Werte + Buttons da',
      (tester) async {
    // Reale Querformat-Metrik des Test-Emulators (~616×394 dp) — hier brach
    // das alte starre Column+Spacer-Layout ab (Punkte/Buttons abgeschnitten).
    tester.view.physicalSize = const Size(1232, 789);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: QuizSummaryScreen(
        lessonTitle: 'Begrüßung',
        direction: QuizDirection.deToHr,
        correctCount: 10,
        totalCount: 10,
        durationSeconds: 26,
        hintsUsed: 0,
        score: 79,
        onRetry: () {},
        onBack: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    for (final label in ['Richtig', 'Trefferquote', 'Zeit', 'Hinweise', 'Punkte']) {
      expect(find.text(label), findsOneWidget, reason: 'Kennzahl "$label" fehlt');
    }
    expect(find.text('79'), findsOneWidget); // Punkte-Wert sichtbar
    expect(find.text('Zur Lektion'), findsOneWidget);
    expect(find.text('Erneut spielen'), findsOneWidget);
  });
}
