enum JokerType {
  ipa('ipa', 'Lautschrift', '🗣️', 2),
  fiftyFifty('50_50', '50/50', '🎲', 1),
  audio('audio', 'Vorlesen', '🔊', 1);

  const JokerType(this.code, this.label, this.emoji, this.cost);

  final String code;
  final String label;
  final String emoji;
  final int cost;

  static JokerType? fromCode(String code) {
    for (final j in JokerType.values) {
      if (j.code == code) return j;
    }
    return null;
  }
}
