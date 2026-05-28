import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocabularies_kroatic/features/quiz/models/joker_type.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_question.dart';
import 'package:vocabularies_kroatic/features/quiz/widgets/joker_bar.dart';

/// Spiegelt `_CenteredScrollable` aus quiz_screen.dart (private), um das
/// Hochformat-Layout des Quiz hier testbar zu machen.
class _CenteredScrollable extends StatelessWidget {
  const _CenteredScrollable({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

QuizQuestion _question() => const QuizQuestion(
      itemId: 'i1',
      prompt: 'kaufen',
      correct: 'kupiti',
      options: ['kupiti', 'kartica', 'lubenica', 'popust'],
      ipaHint: 'ˈkupiti',
      isNewWord: false,
      direction: QuizDirection.deToHr,
      difficulty: 1,
    );

/// Baut das Hochformat-Quizlayout (vereinfacht, aber strukturgleich zu
/// quiz_screen.dart) mit umschaltbarem IPA-Joker.
class _PortraitHarness extends StatefulWidget {
  const _PortraitHarness();
  @override
  State<_PortraitHarness> createState() => _PortraitHarnessState();
}

class _PortraitHarnessState extends State<_PortraitHarness> {
  final Set<JokerType> _used = {};

  @override
  Widget build(BuildContext context) {
    final question = _question();
    final promptBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 80, color: Colors.blue.shade50, child: Text(question.prompt)),
        if (_used.contains(JokerType.ipa) || _used.contains(JokerType.audio)) ...[
          const SizedBox(height: 12),
          JokerReveals(question: question, usedJokers: _used),
        ],
      ],
    );
    final answerBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in question.options)
          Container(height: 60, margin: const EdgeInsets.only(bottom: 8), color: Colors.grey.shade200, child: Text(o)),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CenteredScrollable(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          promptBlock,
                          const SizedBox(height: 18),
                          answerBlock,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _used.add(JokerType.ipa)),
                    child: const Text('IPA'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('IPA-Reveal erscheint im Hochformat nach Joker-Nutzung',
      (tester) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: _PortraitHarness()));
    expect(find.textContaining('ˈkupiti'), findsNothing);

    await tester.tap(find.text('IPA'));
    await tester.pumpAndSettle();

    final ipaFinder = find.textContaining('ˈkupiti');
    expect(ipaFinder, findsOneWidget);
    // Sichtbarkeit: das Reveal muss im Viewport liegen (nicht abgeschnitten).
    final box = tester.getRect(ipaFinder);
    expect(box.top, greaterThanOrEqualTo(0));
    expect(box.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('IPA-Reveal auch bei viel Inhalt (kleiner Screen) sichtbar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: _PortraitHarness()));
    await tester.tap(find.text('IPA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ˈkupiti'), findsOneWidget);
  });
}
