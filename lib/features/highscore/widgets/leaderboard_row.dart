import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardRow extends StatefulWidget {
  const LeaderboardRow({
    super.key,
    required this.entry,
    this.isFriend = false,
    this.isSelf = false,
    this.onSendRequest,
  });

  final LeaderboardEntry entry;
  final bool isFriend;
  final bool isSelf;

  /// Wenn gesetzt: rechts wird ein kleiner Plus-Button gerendert, der bei
  /// Tap die Freundschaftsanfrage absendet. `null` bedeutet: kein Button —
  /// z. B. weil eigener Eintrag, bereits-Freund oder nicht eingeloggt.
  final Future<void> Function()? onSendRequest;

  @override
  State<LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<LeaderboardRow> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _handleSend() async {
    final cb = widget.onSendRequest;
    if (cb == null || _sending || _sent) return;
    setState(() => _sending = true);
    try {
      await cb();
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anfrage an ${widget.entry.displayName} gesendet.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = widget.entry;
    final medal = _medalFor(entry.rank);
    final gamesLabel =
        entry.gamesPlayed == 1 ? '1 Spiel' : '${entry.gamesPlayed} Spiele';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (widget.isFriend) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: scheme.tertiary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gamesLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onSendRequest != null) ...[
                SizedBox(
                  width: 36,
                  height: 36,
                  child: _sent
                      ? Icon(Icons.check, color: scheme.primary)
                      : _sending
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                  Icons.person_add_alt_outlined),
                              tooltip: 'Als Freund hinzufügen',
                              onPressed: _handleSend,
                            ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _formatScore(entry.totalScorePoints),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
}
