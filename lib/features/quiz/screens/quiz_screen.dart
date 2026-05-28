import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/speak_button.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import '../controllers/quiz_session_controller.dart';
import '../models/joker_type.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_format.dart';
import '../models/quiz_question.dart';
import '../widgets/joker_bar.dart';
import '../widgets/quiz_mic_input.dart';
import '../widgets/quiz_option_button.dart';
import '../widgets/quiz_progress_bar.dart';
import '../widgets/quiz_text_input.dart';
import 'quiz_summary_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.direction,
    required this.format,
    this.reviewMode = false,
    this.dailyMode = false,
    this.dueReviewMode = false,
  });

  final String lessonId;
  final String lessonTitle;
  final QuizDirection direction;
  final QuizFormat format;
  final bool reviewMode;
  final bool dailyMode;
  final bool dueReviewMode;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  Timer? _advanceTimer;
  final List<bool?> _correctMask = [];
  int? _autoPlayedIndex;

  QuizSessionArgs get _args => QuizSessionArgs(
        lessonId: widget.lessonId,
        direction: widget.direction,
        format: widget.format,
        reviewMode: widget.reviewMode,
        dailyMode: widget.dailyMode,
        dueReviewMode: widget.dueReviewMode,
      );

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
            hintsUsed: state.jokersUsedTotal,
            score: computeScore(
              correctCount: state.correctCount,
              durationSeconds: state.elapsedSeconds,
              jokerCost: state.jokerCostTotal,
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

    _autoPlayIfNeeded(state, question);

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Querformat (breit & flacher als hoch) → zweispaltig, damit der
            // Inhalt ohne Scrollen passt. Hochformat → einspaltig, vertikal
            // zentriert.
            final isWide = constraints.maxWidth >= 600 &&
                constraints.maxWidth > constraints.maxHeight;

            final progressHeader = Column(
              mainAxisSize: MainAxisSize.min,
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
              ],
            );

            final promptBlock = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.format == QuizFormat.listenSpeak &&
                    !state.isAnswered)
                  _ListenPrompt(
                    langTag: question.direction.promptLangTag,
                    text: question.prompt,
                    onTap: () => _playPrompt(question),
                  )
                else
                  _PromptCard(
                    text: question.prompt,
                    langTag: question.direction.promptLangTag,
                  ),
                if (state.usedJokersThisQuestion.contains(JokerType.ipa) ||
                    state.usedJokersThisQuestion
                        .contains(JokerType.audio)) ...[
                  const SizedBox(height: 12),
                  JokerReveals(
                    question: question,
                    usedJokers: state.usedJokersThisQuestion,
                    onReplayAudio: () => _playCorrectAnswer(question),
                  ),
                ],
              ],
            );

            final answerBlock = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAnswerArea(state, question),
                if (state.isAnswered)
                  _AnswerFeedback(state: state, question: question),
              ],
            );

            final jokerBar = JokerBar(
              question: question,
              format: widget.format,
              usedJokers: state.usedJokersThisQuestion,
              isAnswered: state.isAnswered,
              onUseJoker: (j) {
                ref
                    .read(quizSessionControllerProvider(_args).notifier)
                    .useJoker(j);
                if (j == JokerType.audio) {
                  _playCorrectAnswer(question);
                }
              },
            );

            final showWeiter =
                state.isAnswered && state.wasLastCorrect == false;
            final weiterButton = FilledButton.icon(
              onPressed: () => _advance(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Weiter'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            );

            if (isWide) {
              // Querformat: links Prompt + Jokerleiste, rechts Antworten +
              // Weiter. So bekommt die Antwortliste die volle Höhe.
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _CenteredScrollable(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      progressHeader,
                                      const SizedBox(height: 16),
                                      promptBlock,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              jokerBar,
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _CenteredScrollable(child: answerBlock),
                              ),
                              if (showWeiter) ...[
                                const SizedBox(height: 12),
                                weiterButton,
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Hochformat: einspaltig, Jokerleiste unten über die volle Breite.
            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: kTabletMaxContentWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CenteredScrollable(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              progressHeader,
                              const SizedBox(height: 16),
                              promptBlock,
                              const SizedBox(height: 18),
                              answerBlock,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      jokerBar,
                      if (showWeiter) ...[
                        const SizedBox(height: 12),
                        weiterButton,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnswerArea(QuizSessionState state, QuizQuestion question) {
    switch (widget.format) {
      case QuizFormat.multipleChoice:
        return Column(
          children: [
            for (final opt in question.options)
              Builder(builder: (_) {
                final optState = _optionStateFor(
                  option: opt,
                  question: question,
                  state: state,
                );
                final disabled = state.isAnswered ||
                    optState == QuizOptionState.dimmed ||
                    optState == QuizOptionState.eliminated;
                return QuizOptionButton(
                  label: opt,
                  state: optState,
                  onTap: disabled ? null : () => _handleAnswer(opt, state),
                  onSpeak: () => ref.read(ttsServiceProvider).speak(
                        opt,
                        question.direction.answerLangTag,
                      ),
                );
              }),
          ],
        );
      case QuizFormat.type:
        return QuizTextInput(
          langTag: question.direction.answerLangTag,
          locked: state.isAnswered,
          lastInput: state.lockedAnswer,
          onSubmit: (text) => _handleAnswer(text, state),
        );
      case QuizFormat.speak:
      case QuizFormat.listenSpeak:
        return QuizMicInput(
          langTag: question.direction.answerLangTag,
          locked: state.isAnswered,
          lastInput: state.lockedAnswer,
          onSubmit: (text) => _handleAnswer(text, state),
        );
    }
  }

  void _autoPlayIfNeeded(QuizSessionState state, QuizQuestion question) {
    if (widget.format != QuizFormat.listenSpeak) return;
    if (state.isAnswered) return;
    if (_autoPlayedIndex == state.currentIndex) return;
    _autoPlayedIndex = state.currentIndex;
    Future.microtask(() => _playPrompt(question));
  }

  Future<void> _playPrompt(QuizQuestion question) async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(question.prompt, question.direction.promptLangTag);
  }

  Future<void> _playCorrectAnswer(QuizQuestion question) async {
    final tts = ref.read(ttsServiceProvider);
    await tts.speak(question.correct, question.direction.answerLangTag);
  }

  QuizOptionState _optionStateFor({
    required String option,
    required QuizQuestion question,
    required QuizSessionState state,
  }) {
    if (!state.isAnswered) {
      if (state.usedJokersThisQuestion.contains(JokerType.fiftyFifty)) {
        final dimmed = fiftyFiftyDimmed(
          question: question,
          sessionId: state.sessionId,
          questionOrder: state.currentIndex,
        );
        if (dimmed.contains(option)) return QuizOptionState.eliminated;
      }
      return QuizOptionState.neutral;
    }
    if (option == question.correct) return QuizOptionState.correct;
    if (option == state.lockedAnswer) return QuizOptionState.wrong;
    return QuizOptionState.dimmed;
  }

  Future<void> _handleAnswer(String picked, QuizSessionState state) async {
    final controller =
        ref.read(quizSessionControllerProvider(_args).notifier);
    await controller.answer(picked);
    if (!mounted) return;
    // Tastatur einfahren, damit der Weiter-Button bei falscher Antwort
    // sichtbar bleibt (Schreiben/Sprechen-Modus).
    FocusScope.of(context).unfocus();
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

/// Scrollbarer Bereich, der seinen Inhalt vertikal zentriert, solange er in
/// den sichtbaren Bereich passt, und erst bei Überlänge scrollt.
class _CenteredScrollable extends StatelessWidget {
  const _CenteredScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.text, required this.langTag});

  final String text;
  final String langTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          SpeakButton(
            text: text,
            langTag: langTag,
            color: scheme.onPrimaryContainer,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _ListenPrompt extends StatelessWidget {
  const _ListenPrompt({
    required this.langTag,
    required this.text,
    required this.onTap,
  });

  final String langTag;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.hearing,
                size: 36,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tippe zum Anhören',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.replay,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.state, required this.question});

  final QuizSessionState state;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wasCorrect = state.wasLastCorrect == true;
    final notice = state.spellingNotice;
    final accent = wasCorrect ? Colors.green : Colors.red;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                wasCorrect ? Icons.check_circle : Icons.cancel,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                wasCorrect ? 'Richtig!' : 'Falsch.',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Korrekt: ${question.correct}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SpeakButton(
                text: question.correct,
                langTag: question.direction.answerLangTag,
              ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: 4),
            Text(
              'Achte auf die Schreibweise: $notice',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
