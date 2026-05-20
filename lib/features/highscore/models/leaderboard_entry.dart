class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.totalScorePoints,
    required this.gamesPlayed,
  });

  final int rank;
  final String uid;
  final String displayName;
  final int totalScorePoints;
  final int gamesPlayed;
}
