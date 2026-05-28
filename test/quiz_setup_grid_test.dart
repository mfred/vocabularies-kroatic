import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repräsentative Kachel, strukturgleich zu `_FormatTile` (Material > InkWell
/// > Container mit Row[Icon, Expanded(Text), Icon]) — relevant fürs
/// IntrinsicHeight-Verhalten.
Widget _tile(String label) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_box_outlined),
              const SizedBox(width: 14),
              Expanded(child: Text(label)),
              const Icon(Icons.radio_button_unchecked),
            ],
          ),
        ),
      ),
    );

/// Spiegelt `_buildFormatGrid` aus quiz_setup_screen.dart: 2×2-Grid mit
/// IntrinsicHeight + Row(stretch) in einer vertikalen SingleChildScrollView.
Widget _grid(List<String> labels) {
  final rows = <Widget>[];
  for (var i = 0; i < labels.length; i += 2) {
    if (i > 0) rows.add(const SizedBox(height: 8));
    rows.add(
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _tile(labels[i])),
            const SizedBox(width: 8),
            if (i + 1 < labels.length)
              Expanded(child: _tile(labels[i + 1]))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}

void main() {
  testWidgets('Setup-Grid (Querformat) rendert alle Kacheln + Button',
      (tester) async {
    tester.view.physicalSize = const Size(1233, 670); // Tablet quer
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const labels = ['Vokabelcheck', 'Schreiben', 'Sprechen', 'Hören & Sprechen'];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Spiel wählen'),
                const SizedBox(height: 12),
                _grid(labels),
                const SizedBox(height: 24),
                FilledButton(onPressed: () {}, child: const Text('Quiz starten')),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Kein Layout-Fehler (sonst wäre der Test bereits fehlgeschlagen) und
    // alle 4 Kacheln + Start-Button sind sichtbar gerendert.
    for (final l in labels) {
      final f = find.text(l);
      expect(f, findsOneWidget, reason: 'Kachel "$l" fehlt');
      expect(tester.getSize(f).height, greaterThan(0));
    }
    final btn = find.text('Quiz starten');
    expect(btn, findsOneWidget);
    expect(tester.getSize(btn).height, greaterThan(0));
  });
}
