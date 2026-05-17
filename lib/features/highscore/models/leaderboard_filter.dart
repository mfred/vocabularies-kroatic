import 'leaderboard_range.dart';

class LeaderboardFilter {
  const LeaderboardFilter({required this.range, this.lessonId});

  final LeaderboardRange range;
  final String? lessonId;

  LeaderboardFilter copyWith({LeaderboardRange? range, String? lessonId}) {
    return LeaderboardFilter(
      range: range ?? this.range,
      lessonId: lessonId,
    );
  }

  LeaderboardFilter withRange(LeaderboardRange range) {
    return LeaderboardFilter(range: range, lessonId: lessonId);
  }

  LeaderboardFilter withLessonId(String? lessonId) {
    return LeaderboardFilter(range: range, lessonId: lessonId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardFilter &&
          other.range == range &&
          other.lessonId == lessonId;

  @override
  int get hashCode => Object.hash(range, lessonId);
}
