import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({super.key, required this.entry, this.onTap});

  final LeaderboardEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = _medalFor(entry.rank);

    final minutes = (entry.durationMs ~/ 60000).toString().padLeft(2, '0');
    final seconds =
        ((entry.durationMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final relative = _relativeDate(entry.finishedAt);
    final directionLabel = entry.direction?.compactLabel ?? '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: entry.rank <= 3
                    ? scheme.primary.withValues(alpha: 0.45)
                    : scheme.outlineVariant,
                width: entry.rank <= 3 ? 1.5 : 1,
              ),
            ),
            child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: medal != null
                  ? Text(medal, style: const TextStyle(fontSize: 22))
                  : Text(
                      '${entry.rank}.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.correctCount}/${entry.totalCount} · '
                  '${entry.lessonTitle} · '
                  '$directionLabel · '
                  '$minutes:$seconds · '
                  '$relative',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatScore(entry.scorePoints),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'P',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: scheme.outline,
          ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  static String? _medalFor(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }

  static String _formatScore(int score) {
    final s = score.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _relativeDate(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inSeconds < 60) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} min';
    if (diff.inHours < 24 && now.day == when.day) {
      final hh = when.hour.toString().padLeft(2, '0');
      final mm = when.minute.toString().padLeft(2, '0');
      return 'heute $hh:$mm';
    }
    if (diff.inDays < 7) return 'vor ${diff.inDays} T';
    final d = when.day.toString().padLeft(2, '0');
    final m = when.month.toString().padLeft(2, '0');
    return '$d.$m.${when.year}';
  }
}
