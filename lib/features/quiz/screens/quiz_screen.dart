import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/quiz_session_controller.dart';
import '../models/quiz_direction.dart';
import '../widgets/quiz_hint_panel.dart';
import '../widgets/quiz_option_button.dart';
import '../widgets/quiz_progress_bar.dart';
import 'quiz_summary_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.direction,
  });

  final String lessonId;
  final String lessonTitle;
  final QuizDirection direction;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  Timer? _advanceTimer;
  final List<bool?> _correctMask = [];

  QuizSessionArgs get _args =>
      QuizSessionArgs(lessonId: widget.lessonId, direction: widget.direction);

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quizSessionControllerProvider(_args));
    final theme = Theme.of(context);

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.lessonTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(widget.lessonTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Konnte Quiz nicht starten: $e',
                textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (state) {
        if (state.isFinished) {
          return QuizSummaryScreen(
            lessonTitle: widget.lessonTitle,
            direction: widget.direction,
            correctCount: state.correctCount,
            totalCount: state.totalQuestions,
            durationSeconds: state.elapsedSeconds,
            hintsUsed: state.hintsUsed,
            score: computeScore(
              correctCount: state.correctCount,
              durationSeconds: state.elapsedSeconds,
              hintsUsed: state.hintsUsed,
            ),
            onRetry: () {
              _advanceTimer?.cancel();
              setState(_correctMask.clear);
              ref.invalidate(quizSessionControllerProvider(_args));
            },
            onBack: () => Navigator.of(context).pop(),
          );
        }

        if (!state.hasQuestions) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.lessonTitle)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Diese Lektion enthält keine Items.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return _buildQuiz(context, theme, state);
      },
    );
  }

  Widget _buildQuiz(
    BuildContext context,
    ThemeData theme,
    QuizSessionState state,
  ) {
    final question = state.current!;
    final minutes = (state.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (state.elapsedSeconds % 60).toString().padLeft(2, '0');

    while (_correctMask.length < state.totalQuestions) {
      _correctMask.add(null);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lessonTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.direction.compactLabel} · $minutes:$seconds',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Abbrechen',
            onPressed: () => _confirmExit(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuizProgressBar(
                total: state.totalQuestions,
                currentIndex: state.currentIndex,
                correctMask: _correctMask,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Frage ${state.currentIndex + 1} / ${state.totalQuestions}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PromptCard(
                langLabel: question.direction.promptLang,
                text: question.prompt,
              ),
              const SizedBox(height: 18),
              ...question.options.map((opt) {
                final optState = _optionStateFor(
                  option: opt,
                  question: question,
                  state: state,
                );
                return QuizOptionButton(
                  label: opt,
                  state: optState,
                  onTap: state.isAnswered
                      ? null
                      : () => _handleAnswer(opt, state),
                );
              }),
              const Spacer(),
              QuizHintPanel(
                hint: question.hint,
                isNew: question.isNewWord,
                revealed: state.hintRevealed,
                onReveal: state.isAnswered
                    ? null
                    : () => ref
                        .read(quizSessionControllerProvider(_args).notifier)
                        .revealHint(),
              ),
              const SizedBox(height: 12),
              if (state.isAnswered && state.wasLastCorrect == false)
                FilledButton.icon(
                  onPressed: () => _advance(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Weiter'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  QuizOptionState _optionStateFor({
    required String option,
    required dynamic question,
    required QuizSessionState state,
  }) {
    if (!state.isAnswered) return QuizOptionState.neutral;
    if (option == question.correct) return QuizOptionState.correct;
    if (option == state.lockedAnswer) return QuizOptionState.wrong;
    return QuizOptionState.dimmed;
  }

  Future<void> _handleAnswer(String picked, QuizSessionState state) async {
    final controller =
        ref.read(quizSessionControllerProvider(_args).notifier);
    await controller.answer(picked);
    final updated = ref.read(quizSessionControllerProvider(_args)).value;
    if (updated == null) return;
    setState(() {
      if (state.currentIndex < _correctMask.length) {
        _correctMask[state.currentIndex] = updated.wasLastCorrect ?? false;
      }
    });
    if (updated.wasLastCorrect == true) {
      _advanceTimer?.cancel();
      _advanceTimer = Timer(const Duration(milliseconds: 700), _advance);
    }
  }

  Future<void> _advance() async {
    _advanceTimer?.cancel();
    if (!mounted) return;
    await ref.read(quizSessionControllerProvider(_args).notifier).advance();
  }

  Future<void> _confirmExit(BuildContext context) async {
    final navigator = Navigator.of(context);
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quiz abbrechen?'),
        content: const Text(
          'Der aktuelle Versuch wird nicht in die Bestenliste aufgenommen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Weiter spielen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (exit == true && mounted) {
      navigator.pop();
    }
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.langLabel, required this.text});

  final String langLabel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            langLabel,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
