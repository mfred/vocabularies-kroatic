class StreakReward {
  const StreakReward({required this.streakDay, required this.bonusPoints});

  final int streakDay;
  final int bonusPoints;
}

/// Meilenstein-Stufen: Tag → Bonuspunkte für den nächsten Quiz.
const Map<int, int> kStreakRewardTiers = {
  3: 50,
  7: 150,
  14: 400,
  30: 1000,
  60: 2500,
  100: 5000,
};

int? bonusForStreakDay(int day) => kStreakRewardTiers[day];
