import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../shared/providers.dart';
import '../quiz/models/quiz_direction.dart';
import '../quiz/screens/quiz_screen.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({super.key, required this.lesson});

  final LessonsCacheData lesson;

  @override
  ConsumerState<LessonDetailScreen> createState() =>
      _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  String _stage = 'words';
  QuizDirection _direction = QuizDirection.deToHr;

  int get _totalItems =>
      widget.lesson.wordCount +
      widget.lesson.phraseCount +
      widget.lesson.sentenceCount;

  bool get _canStartQuiz => _totalItems >= 4;

  void _startQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          lessonId: widget.lesson.lessonId,
          lessonTitle: widget.lesson.titleDe,
          direction: _direction,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(lessonItemsProvider(widget.lesson.lessonId));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lesson.titleDe),
            Text(
              widget.lesson.titleHr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'words',
                  label: Text('Wörter (${widget.lesson.wordCount})'),
                  icon: const Icon(Icons.short_text),
                ),
                ButtonSegment(
                  value: 'phrases',
                  label: Text('Phrasen (${widget.lesson.phraseCount})'),
                  icon: const Icon(Icons.notes),
                ),
                ButtonSegment(
                  value: 'sentences',
                  label: Text('Sätze (${widget.lesson.sentenceCount})'),
                  icon: const Icon(Icons.subject),
                ),
              ],
              selected: {_stage},
              showSelectedIcon: false,
              onSelectionChanged: (set) =>
                  setState(() => _stage = set.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Quiz-Richtung',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      SegmentedButton<QuizDirection>(
                        segments: const [
                          ButtonSegment(
                            value: QuizDirection.deToHr,
                            label: Text('🇩🇪 → 🇭🇷'),
                          ),
                          ButtonSegment(
                            value: QuizDirection.hrToDe,
                            label: Text('🇭🇷 → 🇩🇪'),
                          ),
                        ],
                        selected: {_direction},
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onSelectionChanged: (set) =>
                            setState(() => _direction = set.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _canStartQuiz ? _startQuiz : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _canStartQuiz
                          ? 'Quiz starten (10)'
                          : 'Zu wenige Items für ein Quiz',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Fehler: $e',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                ),
              ),
              data: (items) {
                final filtered =
                    items.where((i) => i.stage == _stage).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Keine Einträge in dieser Stage.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ItemCard(item: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIpa = item.hrIpa != null && item.hrIpa!.isNotEmpty;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: 1.2,
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LangChip(label: 'DE', color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.deText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LangChip(label: 'HR', color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.hrText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasIpa) ...[
                        const SizedBox(height: 2),
                        Text(
                          '[${item.hrIpa}]',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _DiffBadge(difficulty: item.difficulty),
              ],
            ),
            if (item.notesDe != null && item.notesDe!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.notesDe!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.difficulty});

  final int difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Schwierigkeit $difficulty/5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < difficulty;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              filled ? Icons.circle : Icons.circle_outlined,
              size: 7,
              color: filled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          );
        }),
      ),
    );
  }
}
