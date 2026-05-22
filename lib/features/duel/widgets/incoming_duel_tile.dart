import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quiz/models/quiz_direction.dart';
import '../duel_providers.dart';
import '../models/duel.dart';
import '../screens/duel_play_screen.dart';
import 'duel_incoming_dialog.dart';

/// Einzeiliger Eintrag „X fordert dich heraus" — annimmt oder lehnt das
/// Duell ab und navigiert bei Annahme direkt in den Play-Screen.
class IncomingDuelTile extends ConsumerWidget {
  const IncomingDuelTile({super.key, required this.duel});

  final Duel duel;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => DuelIncomingDialog(duel: duel),
    );
    if (choice == null || !context.mounted) return;
    final service = ref.read(duelServiceProvider);
    if (choice == 'decline') {
      await service.declineDuel(duel.id);
      return;
    }
    try {
      await service.acceptDuel(duel.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte nicht annehmen: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    final direction = duel.direction == 'hr_de'
        ? QuizDirection.hrToDe
        : QuizDirection.deToHr;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuelPlayScreen(
          lessonTitle: duel.lessonTitle,
          lessonId: duel.lessonId,
          direction: direction,
          rounds: duel.rounds,
          duelId: duel.id,
          challengerTotalMs: duel.challengerResult.totalMs,
          challengerUid: duel.challengerUid,
          opponentUid: duel.opponentUid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.tertiary,
                child: Text(
                  duel.challengerDisplayName.isEmpty
                      ? '?'
                      : duel.challengerDisplayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: scheme.onTertiary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${duel.challengerDisplayName} fordert dich heraus',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Zeit zu schlagen: ${(duel.challengerResult.totalMs / 1000).toStringAsFixed(2)} s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
