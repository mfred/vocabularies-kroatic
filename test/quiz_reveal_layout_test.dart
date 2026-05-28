import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocabularies_kroatic/features/quiz/models/joker_type.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_direction.dart';
import 'package:vocabularies_kroatic/features/quiz/models/quiz_format.dart';
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
      prompt: 'Mann',
      correct: 'Muškarac',
      options: ['Vlada', 'Nedostatak', 'Okoliš', 'Muškarac'],
      ipaHint: 'ˈmuʃkarats',
      isNewWord: false,
      direction: QuizDirection.deToHr,
      difficulty: 1,
    );

/// Repliziert den Hochformat-Zweig aus quiz_screen.dart strukturell exakt
/// (Center > ConstrainedBox(640) > Padding > Column[ Expanded(_Centered…),
/// JokerBar ]) und nutzt die ECHTE JokerBar + JokerReveals.
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
        Container(
          height: 80,
          alignment: Alignment.centerLeft,
          color: Colors.blue.shade50,
          child: Text(question.prompt),
        ),
        if (_used.contains(JokerType.ipa) ||
            _used.contains(JokerType.audio)) ...[
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
          Container(
            height: 88,
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.grey.shade200,
            child: Text(o),
          ),
      ],
    );

    final jokerBar = JokerBar(
      question: question,
      format: QuizFormat.multipleChoice,
      usedJokers: _used,
      isAnswered: false,
      onUseJoker: (j) => setState(() => _used.add(j)),
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
                  jokerBar,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const MaterialApp(home: _PortraitHarness()));
}

void main() {
  for (final size in const [
    Size(800, 1280), // Tablet hochkant
    Size(411, 731), // Phone
    Size(360, 560), // sehr klein, Inhalt > Viewport
  ]) {
    testWidgets('IPA-Reveal sichtbar nach echtem Joker-Tap @ $size',
        (tester) async {
      await _pumpAt(tester, size);

      expect(find.textContaining('ˈmuʃkarats'), findsNothing);

      // Echter Tap auf den Lautschrift-Joker in der echten JokerBar.
      await tester.tap(find.text('Lautschrift'));
      await tester.pumpAndSettle();

      final reveal = find.textContaining('ˈmuʃkarats');
      expect(reveal, findsOneWidget,
          reason: 'Reveal muss nach Joker-Nutzung im Baum sein');

      // Sichtbar = innerhalb des Bildschirms gerendert.
      final box = tester.getRect(reveal);
      expect(box.top, greaterThanOrEqualTo(0.0));
      expect(box.bottom, lessThanOrEqualTo(size.height));
    });
  }
}
