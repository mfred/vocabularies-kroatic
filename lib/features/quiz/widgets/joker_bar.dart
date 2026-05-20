import 'package:flutter/material.dart';

import '../models/joker_availability.dart';
import '../models/joker_type.dart';
import '../models/quiz_format.dart';
import '../models/quiz_question.dart';

class JokerBar extends StatelessWidget {
  const JokerBar({
    super.key,
    required this.question,
    required this.format,
    required this.usedJokers,
    required this.isAnswered,
    required this.onUseJoker,
  });

  final QuizQuestion question;
  final QuizFormat format;
  final Set<JokerType> usedJokers;
  final bool isAnswered;
  final void Function(JokerType) onUseJoker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final anyUsed = usedJokers.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 10),
            child: Text(
              'Joker',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final joker in JokerType.values)
            Expanded(
              child: _JokerButton(
                joker: joker,
                available: jokerAvailable(
                  joker,
                  question: question,
                  format: format,
                ),
                used: usedJokers.contains(joker),
                // Wenn ein anderer Joker bereits genutzt wurde, sperre die
                // restlichen — pro Frage max. ein Joker.
                locked: isAnswered || (anyUsed && !usedJokers.contains(joker)),
                onTap: () => onUseJoker(joker),
              ),
            ),
        ],
      ),
    );
  }
}

class JokerReveals extends StatelessWidget {
  const JokerReveals({
    super.key,
    required this.question,
    required this.usedJokers,
  });

  final QuizQuestion question;
  final Set<JokerType> usedJokers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showIpa =
        usedJokers.contains(JokerType.ipa) && question.ipaHint != null;
    final showPicture = usedJokers.contains(JokerType.picture) &&
        question.pictureIcon != null;
    if (!showIpa && !showPicture) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showIpa)
          _RevealCard(
            emoji: JokerType.ipa.emoji,
            child: Text(
              '[${question.ipaHint}]',
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        if (showPicture) ...[
          if (showIpa) const SizedBox(height: 8),
          _RevealCard(
            emoji: JokerType.picture.emoji,
            child: Icon(
              question.pictureIcon,
              size: 56,
              color: scheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class _JokerButton extends StatelessWidget {
  const _JokerButton({
    required this.joker,
    required this.available,
    required this.used,
    required this.locked,
    required this.onTap,
  });

  final JokerType joker;
  final bool available;
  final bool used;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabled = !available || used || locked;
    final color = used
        ? scheme.outline
        : (disabled ? scheme.outline : scheme.primary);
    String tooltip;
    if (used) {
      tooltip = 'Joker bereits genutzt';
    } else if (!available) {
      tooltip = joker == JokerType.fiftyFifty
          ? 'Nur im Vokabelcheck-Modus'
          : '${joker.label} nicht verfügbar';
    } else {
      tooltip = '${joker.label} (−${joker.cost} P)';
    }
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                joker.emoji,
                style: TextStyle(fontSize: 22, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                joker.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  decoration:
                      used ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              Text(
                '−${joker.cost}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.emoji, required this.child});

  final String emoji;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Deterministische Auswahl der 2 falschen Optionen für 50/50.
List<String> fiftyFiftyDimmed({
  required QuizQuestion question,
  required String sessionId,
  required int questionOrder,
}) {
  final wrongs =
      question.options.where((o) => o != question.correct).toList();
  if (wrongs.length <= 2) return wrongs;
  // Stabiler Pseudo-RNG aus sessionId + questionOrder, damit Re-Renders
  // dieselben Optionen ausgrauen.
  final seed = sessionId.hashCode ^ (questionOrder * 31);
  final sorted = [...wrongs]..sort();
  // Deterministische Rotation: nimm die ersten zwei nach Rotation um seed.
  final n = sorted.length;
  final offset = seed.abs() % n;
  return [sorted[offset], sorted[(offset + 1) % n]];
}
