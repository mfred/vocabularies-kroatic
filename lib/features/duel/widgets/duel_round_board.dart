import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/tablet_constrained.dart';
import '../controllers/duel_play_controller.dart';
import '../models/duel_pair.dart';

/// Zwei-Spalten-Layout für eine Duell-Runde. Jede Karte ist gleichzeitig
/// Draggable und DragTarget — d. h. man kann sowohl die deutsche auf die
/// kroatische ziehen als auch umgekehrt. Drops sind nur zwischen den beiden
/// Seiten erlaubt (links↔rechts), nicht innerhalb einer Seite.
///
/// Korrekter Drop = grüner Fade auf beiden Karten (siehe `_FadingMatchedCard`).
/// Falscher Drop = das fälschlich getroffene Target blinkt rot, wackelt kurz
/// horizontal und löst eine kurze Geräte-Vibration aus; Strafzeit (kDuelPenaltyMs)
/// wird via `registerIncorrectAttempt` registriert.
class DuelRoundBoard extends StatelessWidget {
  const DuelRoundBoard({super.key, required this.controller});

  final DuelPlayController controller;

  @override
  Widget build(BuildContext context) {
    final round = controller.currentRound;
    final matched = controller.matchedItemIds;
    final left = round.pairs;
    final right = round.rightPairs;
    final slotCount = left.length;

    return TabletConstrained(
      maxWidth: kTabletMaxBoardWidth,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < slotCount; i++) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DuelSlotCard(
                      pair: left[i],
                      side: _Side.left,
                      text: left[i].leftText,
                      matched: matched.contains(left[i].itemId),
                      onMatched: () =>
                          controller.registerCorrectMatch(left[i].itemId),
                      onWrongDrop: controller.registerIncorrectAttempt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DuelSlotCard(
                      pair: right[i],
                      side: _Side.right,
                      text: right[i].rightText,
                      matched: matched.contains(right[i].itemId),
                      onMatched: () =>
                          controller.registerCorrectMatch(right[i].itemId),
                      onWrongDrop: controller.registerIncorrectAttempt,
                    ),
                  ),
                ],
              ),
            ),
            if (i < slotCount - 1) const SizedBox(height: 10),
          ],
        ],
      ),
      ),
    );
  }
}

enum _Side { left, right }

class _DragPayload {
  const _DragPayload(this.side, this.itemId);
  final _Side side;
  final String itemId;
}

// Hardcoded Grün-Töne für "matched" — bewusst Theme-unabhängig, weil das
// ColorScheme aus dem blauen Seed (`0xFF1565C0`) eine rosa/rötliche Tertiary
// generiert, was visuell wie "falsch" wirkt.
const Color _kMatchedBg = Color(0xFFDFF5E1);
const Color _kMatchedBorder = Color(0xFF2E7D32);
const Color _kMatchedText = Color(0xFF1B5E20);

// Rot-Töne für falsches Drop-Feedback (kurzer Blink).
const Color _kWrongBg = Color(0xFFFDECEA);
const Color _kWrongBorder = Color(0xFFC62828);
const Color _kWrongText = Color(0xFFB71C1C);

// Sichtbarkeitsfenster der grünen "matched"-Karte, bevor sie ausfaded.
const Duration _kMatchedHold = Duration(milliseconds: 600);
const Duration _kMatchedFade = Duration(milliseconds: 400);

// Shake- und Flash-Dauer für falsches Drop.
const Duration _kShakeDuration = Duration(milliseconds: 350);
const Duration _kWrongFlashDuration = Duration(milliseconds: 400);

class _DuelSlotCard extends StatefulWidget {
  const _DuelSlotCard({
    required this.pair,
    required this.side,
    required this.text,
    required this.matched,
    required this.onMatched,
    required this.onWrongDrop,
  });

  final DuelPair pair;
  final _Side side;
  final String text;
  final bool matched;
  final VoidCallback onMatched;
  final VoidCallback onWrongDrop;

  @override
  State<_DuelSlotCard> createState() => _DuelSlotCardState();
}

class _DuelSlotCardState extends State<_DuelSlotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  bool _wrongFlash = false;
  // Generischer Hover-Indikator beim Drüberziehen — verrät NICHT, ob die
  // Ziel-Karte richtig oder falsch wäre. Diese Information wird erst nach
  // dem Drop sichtbar (grüner Fade oder roter Blink+Shake).
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: _kShakeDuration);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _playWrong() {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _wrongFlash = true);
    _shakeCtrl.forward(from: 0);
    Future.delayed(_kWrongFlashDuration, () {
      if (!mounted) return;
      setState(() => _wrongFlash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.matched) {
      return _FadingMatchedCard(text: widget.text);
    }

    final Color bg;
    final Color border;
    final Color textColor;
    double borderWidth = 1.5;
    if (_wrongFlash) {
      bg = _kWrongBg;
      border = _kWrongBorder;
      textColor = _kWrongText;
      borderWidth = 2.0;
    } else if (_hovering) {
      // Neutraler "Drop hier möglich"-Indikator, ohne Hinweis ob richtig/falsch.
      bg = theme.colorScheme.primaryContainer.withValues(alpha: 0.3);
      border = theme.colorScheme.primary;
      textColor = theme.colorScheme.onSurface;
      borderWidth = 2.0;
    } else {
      bg = theme.colorScheme.surface;
      border = theme.colorScheme.outline;
      textColor = theme.colorScheme.onSurface;
    }

    final card = _WordCard(
      text: widget.text,
      backgroundColor: bg,
      borderColor: border,
      textColor: textColor,
      borderWidth: borderWidth,
    );

    final dragTarget = DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        // Nur cross-side Drops erlauben (keine links→links / rechts→rechts).
        // Kein Match-Check hier — der Hover-Highlight bleibt neutral.
        if (details.data.side == widget.side) return false;
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) {
        if (!mounted) return;
        setState(() => _hovering = false);
      },
      onAcceptWithDetails: (details) {
        final isMatch = details.data.itemId == widget.pair.itemId;
        setState(() => _hovering = false);
        if (isMatch) {
          widget.onMatched();
        } else {
          widget.onWrongDrop();
          _playWrong();
        }
      },
      builder: (context, candidate, rejected) {
        return AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final t = _shakeCtrl.value;
            final shakeX = t == 0
                ? 0.0
                : math.sin(t * math.pi * 4) * 8.0 * (1 - t);
            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: child,
            );
          },
          child: card,
        );
      },
    );

    // Wir wrappen Draggable + DragTarget in ein `Center`, damit das DragTarget
    // nur die natürliche Höhe der `_WordCard` (≈ 60 px + Padding) als
    // Hit-Test-Area belegt — nicht den ganzen IntrinsicHeight-Slot, der durch
    // `crossAxisAlignment: stretch` oft viel höher ist (wenn der Partner-Slot
    // einen längeren, mehrzeiligen Text hat). So fallen Drops in den ober-/
    // unter-leeren Bereich eines Slots als „daneben" durch und lösen keine
    // Strafzeit aus.
    return Center(
      child: Draggable<_DragPayload>(
        data: _DragPayload(widget.side, widget.pair.itemId),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: math.min(MediaQuery.of(context).size.width * 0.42, 320),
            child: _WordCard(
              text: widget.text,
              backgroundColor: theme.colorScheme.primary,
              borderColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
              elevated: true,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: dragTarget,
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.borderWidth = 1.5,
    this.elevated = false,
  });

  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final double borderWidth;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Grüne "matched"-Karte, die sich nach kurzer Hold-Phase auf opacity 0
/// ausblendet. Die Box bleibt im Layout (gleiche Höhe wie aktive Karten),
/// damit nichts springt — nur transparent.
class _FadingMatchedCard extends StatefulWidget {
  const _FadingMatchedCard({required this.text});

  final String text;

  @override
  State<_FadingMatchedCard> createState() => _FadingMatchedCardState();
}

class _FadingMatchedCardState extends State<_FadingMatchedCard> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(_kMatchedHold, () {
      if (!mounted) return;
      setState(() => _opacity = 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: _kMatchedFade,
      curve: Curves.easeOut,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kMatchedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kMatchedBorder, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 18, color: _kMatchedBorder),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _kMatchedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
