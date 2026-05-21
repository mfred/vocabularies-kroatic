import 'package:flutter/material.dart';

import '../controllers/duel_play_controller.dart';
import '../models/duel_pair.dart';

/// Zwei-Spalten-Layout für eine Duell-Runde. Links Draggables (Prompt-Sprache),
/// rechts DragTargets (Antwort-Sprache). Korrekter Drop = beide Karten werden
/// als "matched" eingefärbt (gelocked); falscher Drop = +200 ms Strafe, Karte
/// springt automatisch zurück (Standard-Verhalten von [Draggable.feedback]).
class DuelRoundBoard extends StatelessWidget {
  const DuelRoundBoard({super.key, required this.controller});

  final DuelPlayController controller;

  @override
  Widget build(BuildContext context) {
    final round = controller.currentRound;
    final matched = controller.matchedItemIds;
    final left = round.pairs;
    final right = round.rightPairs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (final p in left) ...[
                  _DraggableWordCard(
                    pair: p,
                    matched: matched.contains(p.itemId),
                    onCanceled: controller.registerIncorrectAttempt,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (final p in right) ...[
                  _DropTargetCard(
                    pair: p,
                    matched: matched.contains(p.itemId),
                    onAccepted: () => controller.registerCorrectMatch(p.itemId),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableWordCard extends StatelessWidget {
  const _DraggableWordCard({
    required this.pair,
    required this.matched,
    required this.onCanceled,
  });

  final DuelPair pair;
  final bool matched;
  final VoidCallback onCanceled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (matched) {
      return _MatchedCard(text: pair.leftText);
    }
    final card = _WordCard(
      text: pair.leftText,
      backgroundColor: theme.colorScheme.surface,
      borderColor: theme.colorScheme.outline,
      textColor: theme.colorScheme.onSurface,
    );
    return Draggable<String>(
      data: pair.itemId,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.42,
          child: _WordCard(
            text: pair.leftText,
            backgroundColor: theme.colorScheme.primary,
            borderColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
            elevated: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      onDraggableCanceled: (_, _) => onCanceled(),
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
      return _MatchedCard(text: widget.pair.rightText);
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

class _MatchedCard extends StatelessWidget {
  const _MatchedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.tertiary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: scheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough,
                decorationColor:
                    scheme.onTertiaryContainer.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
