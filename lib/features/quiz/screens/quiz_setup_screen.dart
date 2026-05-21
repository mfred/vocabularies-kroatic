import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../shared/providers.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_format.dart';
import 'quiz_screen.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  const QuizSetupScreen({
    super.key,
    required this.lesson,
    this.reviewMode = false,
  });

  final LessonsCacheData lesson;
  final bool reviewMode;

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  QuizFormat _format = QuizFormat.multipleChoice;

  int get _totalItems =>
      widget.lesson.wordCount +
      widget.lesson.phraseCount +
      widget.lesson.sentenceCount;

  IconData _iconForFormat(QuizFormat f) {
    switch (f) {
      case QuizFormat.multipleChoice:
        return Icons.check_box_outlined;
      case QuizFormat.type:
        return Icons.edit_outlined;
      case QuizFormat.speak:
        return Icons.mic_none_outlined;
      case QuizFormat.listenSpeak:
        return Icons.hearing;
    }
  }

  void _startQuiz(QuizDirection direction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          lessonId: widget.lesson.lessonId,
          lessonTitle: widget.lesson.titleDe,
          direction: direction,
          format: _format,
          reviewMode: widget.reviewMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = ref.watch(preferredDirectionProvider);
    final reviewCountAsync = widget.reviewMode
        ? ref.watch(wrongItemsCountProvider(widget.lesson.lessonId))
        : null;
    final reviewCount = reviewCountAsync?.maybeWhen(
          data: (n) => n,
          orElse: () => null,
        );
    final canStartNormal = !widget.reviewMode && _totalItems >= 4;
    final canStartReview = widget.reviewMode && (reviewCount ?? 0) >= 1;
    final canStart = canStartNormal || canStartReview;

    final String buttonLabel;
    if (widget.reviewMode) {
      if (reviewCount == null) {
        buttonLabel = 'Lade …';
      } else if (reviewCount == 0) {
        buttonLabel = 'Keine offenen Fehler';
      } else {
        final n = reviewCount > 10 ? 10 : reviewCount;
        buttonLabel = 'Fehler wiederholen ($n)';
      }
    } else {
      buttonLabel = canStartNormal
          ? 'Quiz starten (10)'
          : 'Zu wenige Items für ein Quiz';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.reviewMode ? 'Fehler ausbessern' : 'Quiz starten'),
            Text(
              widget.lesson.titleDe,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DirectionPicker(
                direction: direction,
                onChanged: (d) =>
                    ref.read(preferredDirectionProvider.notifier).set(d),
              ),
              const SizedBox(height: 12),
              if (ref
                      .watch(doublePointsActiveProvider)
                      .maybeWhen(data: (v) => v, orElse: () => false))
                _DoublePointsBanner(),
              const SizedBox(height: 8),
              Text(
                'Spiel wählen',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final f in QuizFormat.values) ...[
                _FormatTile(
                  icon: _iconForFormat(f),
                  label: f.label,
                  selected: _format == f,
                  onTap: () => setState(() => _format = f),
                ),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: canStart ? () => _startQuiz(direction) : null,
                icon: Icon(
                  widget.reviewMode ? Icons.refresh : Icons.play_arrow,
                ),
                label: Text(buttonLabel),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({required this.direction, required this.onChanged});

  final QuizDirection direction;
  final ValueChanged<QuizDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeHr = direction == QuizDirection.deToHr;
    final from = isDeHr ? '🇩🇪' : '🇭🇷';
    final to = isDeHr ? '🇭🇷' : '🇩🇪';
    final fromLabel = isDeHr ? 'Deutsch' : 'Kroatisch';
    final toLabel = isDeHr ? 'Kroatisch' : 'Deutsch';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz-Richtung',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$from $fromLabel  →  $to $toLabel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Richtung wechseln',
            onPressed: () => onChanged(
              isDeHr ? QuizDirection.hrToDe : QuizDirection.deToHr,
            ),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final bg = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.surface;
    final fg = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: fg,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary)
              else
                Icon(Icons.radio_button_unchecked,
                    color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}


class _DoublePointsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Doppel-Punkte-Boost aktiv — dieses Quiz zählt ×2',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

