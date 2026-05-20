import 'package:flutter/material.dart';

Future<void> showScoreExplanationDialog(BuildContext context) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Wie werden die Punkte berechnet?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Punkte = Treffer × 100  +  Zeit-Bonus  −  Joker-Strafen',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            const _Bullet(
              text: '100 Punkte pro richtiger Antwort '
                  '→ bis zu 1 000 P bei 10/10.',
            ),
            const _Bullet(
              text: 'Zeit-Bonus: 600 minus Sekunden Spielzeit, '
                  'gekappt auf 0…600. '
                  '0 s → +600, 1 min → +540, 5 min → +300, '
                  '10 min und mehr → 0.',
            ),
            const _Bullet(text: 'Lautschrift-Joker: −15 P pro Nutzung.'),
            const _Bullet(text: '50/50-Joker: −5 P pro Nutzung.'),
            const _Bullet(text: 'Bild-Joker: −10 P pro Nutzung.'),
            const _Bullet(text: 'Negative Summen werden auf 0 gesetzt.'),
            const _Bullet(
              text: 'Bestenliste: pro Spieler werden alle Punkte über '
                  'alle Spiele im gewählten Zeitraum summiert.',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Beispiel\n'
                '8 richtig in 4:12 mit 2× IPA + 1× 50/50\n'
                '→ 800 + (600 − 252) − (2·5 + 15) = 1 123 P',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Verstanden'),
        ),
      ],
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
