import 'package:flutter/material.dart';

import '../controllers/duel_play_controller.dart';
import '../models/duel_pair.dart';

/// Zwei-Spalten-Layout für eine Duell-Runde. Links Draggables (Prompt-Sprache),
/// rechts DragTargets (Antwort-Sprache). Korrekter Drop = beide Karten werden
/// als "matched" eingefärbt (gelocked); falscher Drop = +200 ms Strafe, Karte
/// springt automatisch zurück (Standard-Verhalten von [Draggable.feedback]).
///
/// Pro Slot werden linke und rechte Karte über eine `IntrinsicHeight`-Row auf
/// gleiche Höhe gezwungen, damit das Layout stabil bleibt, auch wenn ein Text
/// umbricht.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < slotCount; i++) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DraggableWordCard(
                      pair: left[i],
                      matched: matched.contains(left[i].itemId),
                      onCanceled: controller.registerIncorrectAttempt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropTargetCard(
                      pair: right[i],
                      matched: matched.contains(right[i].itemId),
                      onAccepted: () =>
                          controller.registerCorrectMatch(right[i].itemId),
                    ),
                  ),
                ],
              ),
            ),
            if (i < slotCount - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// Hardcoded Grün-Töne für "matched" — bewusst Theme-unabhängig, weil das
// ColorScheme aus dem blauen Seed (`0xFF1565C0`) eine rosa/rötliche Tertiary
// generiert, was visuell wie "falsch" wirkt.
const Color _kMatchedBg = Color(0xFFDFF5E1);
const Color _kMatchedBorder = Color(0xFF2E7D32);
const Color _kMatchedText = Color(0xFF1B5E20);

// Sichtbarkeitsfenster der grünen "matched"-Karte, bevor sie ausfaded.
const Duration _kMatchedHold = Duration(milliseconds: 600);
const Duration _kMatchedFade = Duration(milliseconds: 400);

class _DraggableWordCard extends StatefulWidget {
  const _DraggableWordCard({
    required this.pair,
    required this.matched,
    required this.onCanceled,
  });

  final DuelPair pair;
  final bool matched;
  final VoidCallback onCanceled;

  @override
  State<_DraggableWordCard> createState() => _DraggableWordCardState();
}

class _DraggableWordCardState extends State<_DraggableWordCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.matched) {
      return _FadingMatchedCard(text: widget.pair.leftText);
    }
    final card = _WordCard(
      text: widget.pair.leftText,
      backgroundColor: theme.colorScheme.surface,
      borderColor: theme.colorScheme.outline,
      textColor: theme.colorScheme.onSurface,
    );
    return Draggable<String>(
      data: widget.pair.itemId,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.42,
          child: _WordCard(
            text: widget.pair.leftText,
            backgroundColor: theme.colorScheme.primary,
            borderColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
            elevated: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      onDraggableCanceled: (_, _) => widget.onCanceled(),
      child: card,
    );
  }
}

class _DropTargetCard extends StatefulWidget {
  const _DropTargetCard({
    required this.pair,
    required this.matched,
    required this.onAccepted,
  });

  final DuelPair pair;
  final bool matched;
  final VoidCallback onAccepted;

  @override
  State<_DropTargetCard> createState() => _DropTargetCardState();
}

class _DropTargetCardState extends State<_DropTargetCard> {
  bool _hoverCorrect = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.matched) {
      return _FadingMatchedCard(text: widget.pair.rightText);
    }
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final isMatch = details.data == widget.pair.itemId;
        setState(() => _hoverCorrect = isMatch);
        return isMatch;
      },
      onLeave: (_) => setState(() => _hoverCorrect = false),
      onAcceptWithDetails: (_) {
        setState(() => _hoverCorrect = false);
        widget.onAccepted();
      },
      builder: (context, candidate, rejected) {
        final highlight = _hoverCorrect;
        return _WordCard(
          text: widget.pair.rightText,
          backgroundColor: highlight
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderColor: highlight
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          textColor: highlight
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
          borderWidth: highlight ? 2.0 : 1.5,
        );
      },
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
