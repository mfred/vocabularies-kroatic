import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Auswahl der DiceBear-Styles, die im AvatarPickerSheet zur Wahl stehen.
/// Der erste Eintrag ist der App-Default für unverifizierte/alte Profile.
const List<String> kDiceBearStyles = <String>[
  'lorelei',
  'bottts',
  'avataaars',
  'pixel-art',
  'fun-emoji',
  'notionists',
  'adventurer',
  'miniavs',
  'personas',
  'thumbs',
  'shapes',
  'identicon',
];

const String kDefaultAvatarStyle = 'lorelei';

/// Deterministischer Avatar via [DiceBear](https://www.dicebear.com).
///
/// Aus dem `seed` (i. d. R. die UID des Users) wird per HTTP ein SVG geladen.
/// Solange das SVG noch nicht da ist oder fehlschlägt, zeigt das Widget
/// einen Initial-Fallback (erstes Zeichen aus `fallbackText`) — damit
/// funktioniert die UI auch komplett offline (nur ohne hübsches Bild).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.style = 'lorelei',
    this.fallbackText,
    this.fallbackColor,
    this.fallbackTextColor,
  });

  /// Eindeutige Seed — typischerweise die UID. Stabiler Seed → stabiler Avatar.
  final String seed;

  /// Quadratische Größe in Logical Pixels.
  final double size;

  /// DiceBear-Style-ID (z. B. `lorelei`, `bottts`, `avataaars`, `pixel-art`).
  final String style;

  /// Text, aus dem das Initial-Fallback gebaut wird (z. B. Anzeigename).
  final String? fallbackText;

  /// Hintergrundfarbe fürs Fallback (Default: `primaryContainer`).
  final Color? fallbackColor;

  /// Text-Farbe fürs Fallback (Default: `onPrimaryContainer`).
  final Color? fallbackTextColor;

  String _initial() {
    final t = (fallbackText ?? '').trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = fallbackColor ?? scheme.primaryContainer;
    final fg = fallbackTextColor ?? scheme.onPrimaryContainer;
    final url =
        'https://api.dicebear.com/9.x/$style/svg?seed=${Uri.encodeQueryComponent(seed)}';

    final placeholder = Center(
      child: Text(
        _initial(),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: bg,
        alignment: Alignment.center,
        child: SvgPicture.network(
          url,
          width: size,
          height: size,
          placeholderBuilder: (_) => placeholder,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
