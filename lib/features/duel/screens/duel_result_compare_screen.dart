import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import '../duel_providers.dart';
import '../models/duel.dart';

/// Endbild nach Abschluss eines Online-Duells. Live aus Firestore, damit
/// beide Spieler bei Aufruf den aktuellen Stand sehen.
class DuelResultCompareScreen extends ConsumerWidget {
  const DuelResultCompareScreen({super.key, required this.duelId});

  final String duelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myUid = ref.watch(authStateProvider).value?.uid;
    final duelAsync = ref.watch(duelByIdProvider(duelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duell-Ergebnis'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: SafeArea(
        child: duelAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (duel) {
            if (duel == null) {
              return const Center(child: Text('Duell nicht gefunden.'));
            }
            if (!duel.isCompleted || duel.opponentResult == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Warte auf das Ergebnis von ${duel.opponentResult == null ? duel.opponentDisplayName : duel.challengerDisplayName} …',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }
            return _CompletedView(duel: duel, myUid: myUid);
          },
        ),
      ),
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({required this.duel, required this.myUid});

  final Duel duel;
  final String? myUid;

  String _formatMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final centi = (ms % 1000) ~/ 10;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.'
          '${centi.toString().padLeft(2, '0')}';
    }
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final opponent = duel.opponentResult!;
    final challenger = duel.challengerResult;
    final iAmChallenger = myUid == duel.challengerUid;
    final iAmOpponent = myUid == duel.opponentUid;
    final iWon = (iAmChallenger && duel.winnerUid == duel.challengerUid) ||
        (iAmOpponent && duel.winnerUid == duel.opponentUid);

    final myMs = iAmChallenger ? challenger.totalMs : opponent.totalMs;
    final theirMs = iAmChallenger ? opponent.totalMs : challenger.totalMs;
    final diffMs = (myMs - theirMs).abs();

    final outcomeEmoji = iWon ? '🏆' : '🥈';
    final outcomeText = iWon ? 'Gewonnen!' : 'Verloren';
    final outcomeColor = iWon ? scheme.tertiary : scheme.error;

    return LayoutBuilder(
      builder: (context, constraints) {
        return TabletConstrained(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
          const SizedBox(height: 8),
          Center(child: Text(outcomeEmoji, style: const TextStyle(fontSize: 64))),
          const SizedBox(height: 8),
          Text(
            outcomeText,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: outcomeColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            iWon
                ? '${_formatMs(diffMs)} schneller als ${iAmChallenger ? duel.opponentDisplayName : duel.challengerDisplayName}'
                : '${_formatMs(diffMs)} langsamer als ${iAmChallenger ? duel.opponentDisplayName : duel.challengerDisplayName}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _PlayerCard(
            name: duel.challengerDisplayName,
            isMe: iAmChallenger,
            isWinner: duel.winnerUid == duel.challengerUid,
            result: challenger,
            format: _formatMs,
          ),
          const SizedBox(height: 10),
          _PlayerCard(
            name: duel.opponentDisplayName,
            isMe: iAmOpponent,
            isWinner: duel.winnerUid == duel.opponentUid,
            result: opponent,
            format: _formatMs,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.home),
            label: const Text('Zurück zur Übersicht'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.name,
    required this.isMe,
    required this.isWinner,
    required this.result,
    required this.format,
  });

  final String name;
  final bool isMe;
  final bool isWinner;
  final DuelPlayerResult result;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = isWinner
        ? scheme.tertiaryContainer.withValues(alpha: 0.6)
        : scheme.surfaceContainerLow;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWinner ? scheme.tertiary : scheme.outlineVariant,
          width: isWinner ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('🏆', style: TextStyle(fontSize: 20)),
                ),
              Expanded(
                child: Text(
                  isMe ? '$name (du)' : name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                format(result.totalMs),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < result.roundsMs.length; i++) ...[
                Expanded(
                  child: _RoundChip(
                    index: i + 1,
                    ms: result.roundsMs[i],
                    penaltyMs: result.penaltiesMs.length > i
                        ? result.penaltiesMs[i]
                        : 0,
                    format: format,
                  ),
                ),
                if (i < result.roundsMs.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({
    required this.index,
    required this.ms,
    required this.penaltyMs,
    required this.format,
  });

  final int index;
  final int ms;
  final int penaltyMs;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text('R$index',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              )),
          const SizedBox(height: 2),
          Text(
            format(ms),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (penaltyMs > 0)
            Text(
              '+${format(penaltyMs)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
