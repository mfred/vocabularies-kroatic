class ItemAttemptStats {
  const ItemAttemptStats({
    required this.seenCount,
    required this.wrongCount,
    required this.lastCorrect,
    required this.lastAtMs,
  });

  factory ItemAttemptStats.empty() => const ItemAttemptStats(
        seenCount: 0,
        wrongCount: 0,
        lastCorrect: null,
        lastAtMs: null,
      );

  final int seenCount;
  final int wrongCount;
  final bool? lastCorrect;
  final int? lastAtMs;

  bool get isUnseen => seenCount == 0;
  bool get isStumbled =>
      seenCount >= 1 && (wrongCount >= 1 || lastCorrect == false);
  bool get isMastered =>
      seenCount >= 1 && wrongCount == 0 && lastCorrect == true;

  ItemAttemptStats applyAttempt({
    required bool wasCorrect,
    required int atMs,
  }) {
    if (lastAtMs != null && atMs < lastAtMs!) {
      // Aus historischer Reihenfolge: ältere Attempts dürfen lastCorrect/lastAtMs nicht überschreiben.
      return ItemAttemptStats(
        seenCount: seenCount + 1,
        wrongCount: wrongCount + (wasCorrect ? 0 : 1),
        lastCorrect: lastCorrect,
        lastAtMs: lastAtMs,
      );
    }
    return ItemAttemptStats(
      seenCount: seenCount + 1,
      wrongCount: wrongCount + (wasCorrect ? 0 : 1),
      lastCorrect: wasCorrect,
      lastAtMs: atMs,
    );
  }
}
