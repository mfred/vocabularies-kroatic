import 'leaderboard_range.dart';

class LeaderboardFilter {
  const LeaderboardFilter({required this.range});

  final LeaderboardRange range;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardFilter && other.range == range;

  @override
  int get hashCode => range.hashCode;
}
