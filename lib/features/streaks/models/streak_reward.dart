class StreakReward {
  const StreakReward({required this.streakDay, required this.bonusPoints});

  final int streakDay;
  final int bonusPoints;
}

/// Meilenstein-Stufen: Tag → Bonuspunkte für den nächsten Quiz.
/// Skala an Score-Formel x20 angepasst (Iteration 21). Tag 7 ist die
/// „Woche-durchgehalten"-Hürde — saftiger als die anteilig runter-
/// skalte Stufe (~ein ganzes Quiz wert).
const Map<int, int> kStreakRewardTiers = {
  3: 3,
  7: 50,
  14: 30,
  30: 100,
  60: 200,
  100: 500,
};

int? bonusForStreakDay(int day) => kStreakRewardTiers[day];
