import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'dart:convert';

import '../../../core/database/database.dart' hide StreakReward;
import '../../../shared/firebase_status.dart';
import '../../../shared/providers.dart';
import '../models/joker_type.dart';
import '../models/quiz_direction.dart';
import '../models/quiz_format.dart';
import '../models/quiz_question.dart';
import '../services/answer_evaluator.dart';
import '../services/quiz_builder.dart';

class QuizSessionArgs {
  const QuizSessionArgs({
    required this.lessonId,
    required this.direction,
    required this.format,
  });

  final String lessonId;
  final QuizDirection direction;
  final QuizFormat format;

  String get sessionMode => '${format.code}_${direction.code}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizSessionArgs &&
          other.lessonId == lessonId &&
          other.direction == direction &&
          other.format == format;

  @override
  int get hashCode => Object.hash(lessonId, direction, format);
}

class QuizSessionState {
  const QuizSessionState({
    required this.sessionId,
    required this.questions,
    required this.currentIndex,
    required this.correctCount,
    required this.jokersUsedTotal,
    required this.jokerCostTotal,
    required this.usedJokersThisQuestion,
    required this.lockedAnswer,
    required this.wasLastCorrect,
    required this.spellingNotice,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.isFinished,
  });

  final String sessionId;
  final List<QuizQuestion> questions;
  final int currentIndex;
  final int correctCount;
  final int jokersUsedTotal;
  final int jokerCostTotal;
  final Set<JokerType> usedJokersThisQuestion;
  final String? lockedAnswer;
  final bool? wasLastCorrect;
  final String? spellingNotice;
  final int startedAt;
  final int elapsedSeconds;
  final bool isFinished;

  bool get hasQuestions => questions.isNotEmpty;
  QuizQuestion? get current =>
      hasQuestions && currentIndex < questions.length
          ? questions[currentIndex]
          : null;
  int get totalQuestions => questions.length;
  bool get isAnswered => lockedAnswer != null;

  QuizSessionState copyWith({
    int? currentIndex,
    int? correctCount,
    int? jokersUsedTotal,
    int? jokerCostTotal,
    Set<JokerType>? usedJokersThisQuestion,
    String? lockedAnswer,
    bool clearLockedAnswer = false,
    bool? wasLastCorrect,
    bool clearWasLastCorrect = false,
    String? spellingNotice,
    bool clearSpellingNotice = false,
    int? elapsedSeconds,
    bool? isFinished,
  }) {
    return QuizSessionState(
      sessionId: sessionId,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      jokersUsedTotal: jokersUsedTotal ?? this.jokersUsedTotal,
      jokerCostTotal: jokerCostTotal ?? this.jokerCostTotal,
      usedJokersThisQuestion:
          usedJokersThisQuestion ?? this.usedJokersThisQuestion,
      lockedAnswer:
          clearLockedAnswer ? null : (lockedAnswer ?? this.lockedAnswer),
      wasLastCorrect:
          clearWasLastCorrect ? null : (wasLastCorrect ?? this.wasLastCorrect),
      spellingNotice: clearSpellingNotice
          ? null
          : (spellingNotice ?? this.spellingNotice),
      startedAt: startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

int computeScore({
  required int correctCount,
  required int durationSeconds,
  required int jokerCost,
}) {
  final int timeBonus = ((600 - durationSeconds).clamp(0, 600)).toInt();
  final int raw = correctCount * 100 + timeBonus - jokerCost;
  return raw < 0 ? 0 : raw;
}

class QuizSessionController extends AsyncNotifier<QuizSessionState> {
  QuizSessionController(this._args);

  final QuizSessionArgs _args;
  Timer? _ticker;
  int _questionStartMs = 0;
  final Uuid _uuid = const Uuid();

  @override
  Future<QuizSessionState> build() async {
    ref.onDispose(() => _ticker?.cancel());
    final db = ref.read(databaseProvider);
    final player = await ref.read(currentPlayerProvider.future);
    final builder = QuizBuilder(db);
    final questions = await builder.build(
      lessonId: _args.lessonId,
      playerId: player.id,
      direction: _args.direction,
    );
    final sessionId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertQuizSession(
      QuizSessionsCompanion.insert(
        id: sessionId,
        playerId: player.id,
        lessonId: _args.lessonId,
        mode: Value(_args.sessionMode),
        direction: Value(_args.direction.code),
        startedAt: now,
        totalCount: Value(questions.length),
      ),
    );
    _questionStartMs = now;
    _startTicker();
    return QuizSessionState(
      sessionId: sessionId,
      questions: questions,
      currentIndex: 0,
      correctCount: 0,
      jokersUsedTotal: 0,
      jokerCostTotal: 0,
      usedJokersThisQuestion: const {},
      lockedAnswer: null,
      wasLastCorrect: null,
      spellingNotice: null,
      startedAt: now,
      elapsedSeconds: 0,
      isFinished: false,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state.value;
      if (current == null || current.isFinished) return;
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - current.startedAt) ~/ 1000;
      state = AsyncData(current.copyWith(elapsedSeconds: elapsed));
    });
  }

  void useJoker(JokerType joker) {
    final current = state.value;
    if (current == null || current.isAnswered) return;
    // Max. ein Joker pro Frage.
    if (current.usedJokersThisQuestion.isNotEmpty) return;
    final next = {...current.usedJokersThisQuestion, joker};
    state = AsyncData(current.copyWith(
      usedJokersThisQuestion: next,
      jokersUsedTotal: current.jokersUsedTotal + 1,
      jokerCostTotal: current.jokerCostTotal + joker.cost,
    ));
  }

  Future<void> answer(String picked) async {
    final current = state.value;
    if (current == null || current.isAnswered) return;
    final question = current.current;
    if (question == null) return;

    final eval = const AnswerEvaluator().evaluate(picked, question.correct);
    final wasCorrect = eval.isCorrect;
    final spellingNotice = eval.hasSpellingNotice ? question.correct : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final responseMs = now - _questionStartMs;

    final db = ref.read(databaseProvider);
    final usedJokers = current.usedJokersThisQuestion;
    final jokersJson = usedJokers.isEmpty
        ? null
        : jsonEncode(usedJokers.map((j) => j.code).toList());
    await db.insertQuizAttempt(
      QuizAttemptsCompanion.insert(
        id: _uuid.v4(),
        sessionId: current.sessionId,
        itemId: question.itemId,
        questionOrder: current.currentIndex,
        wasCorrect: wasCorrect,
        hintUsed: Value(usedJokers.isNotEmpty),
        responseMs: responseMs,
        pickedOption: Value(picked),
        jokersJson: Value(jokersJson),
        answeredAt: now,
      ),
    );

    state = AsyncData(current.copyWith(
      lockedAnswer: picked,
      wasLastCorrect: wasCorrect,
      spellingNotice: spellingNotice,
      clearSpellingNotice: spellingNotice == null,
      correctCount: current.correctCount + (wasCorrect ? 1 : 0),
    ));
  }

  Future<void> advance() async {
    final current = state.value;
    if (current == null || !current.isAnswered) return;
    final nextIndex = current.currentIndex + 1;
    if (nextIndex >= current.questions.length) {
      await _finish();
      return;
    }
    _questionStartMs = DateTime.now().millisecondsSinceEpoch;
    state = AsyncData(current.copyWith(
      currentIndex: nextIndex,
      clearLockedAnswer: true,
      clearWasLastCorrect: true,
      clearSpellingNotice: true,
      usedJokersThisQuestion: const {},
    ));
  }

  Future<void> _finish() async {
    final current = state.value;
    if (current == null) return;
    _ticker?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = now - current.startedAt;
    final durationSeconds = durationMs ~/ 1000;
    final baseScore = computeScore(
      correctCount: current.correctCount,
      durationSeconds: durationSeconds,
      jokerCost: current.jokerCostTotal,
    );
    final db = ref.read(databaseProvider);
    final player = await ref.read(currentPlayerProvider.future);
    final pendingBonus = await db.getPendingBonusPoints(player.id);
    final finalScore = baseScore + pendingBonus;
    await db.finalizeQuizSession(
      sessionId: current.sessionId,
      finishedAt: now,
      durationMs: durationMs,
      correctCount: current.correctCount,
      totalCount: current.questions.length,
      hintsUsed: current.jokersUsedTotal,
      scorePoints: finalScore,
    );
    if (pendingBonus > 0) {
      await db.clearPendingBonusPoints(player.id);
    }
    state = AsyncData(current.copyWith(
      isFinished: true,
      elapsedSeconds: durationSeconds,
    ));
    // Streak könnte sich nach Session geändert haben (neuer Tag).
    ref.invalidate(currentStreakProvider);
    // Reward erst NACH der Wertung dieser Session prüfen — sonst würde der
    // Bonus für genau diese Session schon mit eingerechnet.
    ref.invalidate(streakRewardCheckProvider);
    // Falls eingeloggt: Score in den globalen Leaderboard hochladen.
    // Fire & forget — Offline-first, kein UI-Block bei Fehler.
    if (FirebaseStatus.instance.isReady &&
        ref.read(firebaseAuthProvider).currentUser != null) {
      unawaited(
        ref
            .read(remoteLeaderboardServiceProvider)
            .uploadSession(current.sessionId)
            .catchError((Object e) {
          // Schluck den Fehler — Score bleibt lokal, das ist ok.
        }),
      );
    }
  }
}

final quizSessionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<QuizSessionController, QuizSessionState, QuizSessionArgs>(
  QuizSessionController.new,
);
