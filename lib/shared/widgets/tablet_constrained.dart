import 'package:flutter/material.dart';

/// Maximale Inhaltsbreite auf Tablets/Desktop. Bis zu dieser Breite dehnt
/// sich der Content; darüber bleibt er zentriert mit Rand.
const double kTabletMaxContentWidth = 640.0;

/// Breitere Variante für Inhalte, die mehr horizontalen Raum brauchen
/// (z. B. das Duell-Drag-and-Drop-Board mit zwei nebeneinanderliegenden
/// Karten-Spalten).
const double kTabletMaxBoardWidth = 720.0;

/// Wrapper, der den Child auf Tablets/Desktop horizontal zentriert und in
/// der Breite begrenzt. Auf Phones (Breite < maxWidth) hat er keinen
/// sichtbaren Effekt — der Child nimmt die volle Breite wie zuvor.
class TabletConstrained extends StatelessWidget {
  const TabletConstrained({
    super.key,
    required this.child,
    this.maxWidth = kTabletMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
