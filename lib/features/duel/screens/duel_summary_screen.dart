import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/screens/verify_email_screen.dart';
import '../../friends/friends_providers.dart';
import '../../friends/models/user_profile.dart';
import '../../quiz/models/quiz_direction.dart';
import '../../../shared/firebase_status.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/tablet_constrained.dart';
import '../duel_providers.dart';
import '../duel_time_format.dart';
import '../models/duel_pair.dart';
import '../models/duel_run_result.dart';
import '../widgets/duel_friend_picker_dialog.dart';

/// Endbild nach 3 Runden Challenger-Lauf: Rundenzeiten + Gesamtzeit, plus
/// "Freund herausfordern". Bei Tap öffnet sich der FriendPicker; nach
/// Auswahl wird ein Firestore-Duel-Doc angelegt.
class DuelSummaryScreen extends ConsumerStatefulWidget {
  const DuelSummaryScreen({
    super.key,
    required this.lessonTitle,
    required this.lessonId,
    required this.direction,
    required this.rounds,
    required this.result,
  });

  final String lessonTitle;
  final String lessonId;
  final QuizDirection direction;
  final List<DuelRound> rounds;
  final DuelRunResult result;

  @override
  ConsumerState<DuelSummaryScreen> createState() => _DuelSummaryScreenState();
}

class _DuelSummaryScreenState extends ConsumerState<DuelSummaryScreen> {
  bool _sending = false;

  Future<void> _challengeFriend() async {
    // Sofort visuelles Feedback — sonst wirkt der Tap wie "nichts passiert",
    // solange das Profil noch lädt.
    setState(() => _sending = true);
    try {
      // Erst Auth-State prüfen — das ist die Quelle der Wahrheit für "ist
      // eingeloggt". `myUserProfileProvider` ist ein Firestore-Stream und
      // kann beim Tap noch leer sein, obwohl der User längst angemeldet ist
      // (Race zwischen FirebaseAuth und Firestore-Profil-Stream).
      final authUser = ref.read(authStateProvider).value;
      if (authUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bitte zuerst anmelden, um Freunde herauszufordern.',
            ),
          ),
        );
        return;
      }
      var me = ref.read(myUserProfileProvider).value;
      if (me == null) {
        try {
          me = await ref
              .read(userProfileServiceProvider)
              .ensureProfile(authUser);
        } catch (_) {
          me = await ref
              .read(userProfileServiceProvider)
              .getByUid(authUser.uid);
        }
      }
      if (me == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profil konnte nicht geladen werden. Bitte erneut versuchen.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      final picked = await showDialog<UserProfile>(
        context: context,
        builder: (_) => const DuelFriendPickerDialog(),
      );
      if (picked == null || !mounted) return;
      await ref.read(duelServiceProvider).createChallenge(
            challengerUid: me.uid,
            challengerDisplayName: me.displayName,
            opponentUid: picked.uid,
            opponentDisplayName: picked.displayName,
            lessonId: widget.lessonId,
            lessonTitle: widget.lessonTitle,
            direction: widget.direction,
            rounds: widget.rounds,
            challengerRun: widget.result,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Herausforderung an ${picked.displayName} gesendet.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Liefert je nach Auth-Zustand den passenden Primär-Button:
  /// herausfordern / Email bestätigen / Anmelden / nicht verfügbar.
  Widget _buildPrimaryAction({
    required BuildContext context,
    required bool firebaseReady,
    required bool isLoggedIn,
    required bool isVerified,
    required bool canChallenge,
    required String? userEmail,
  }) {
    const buttonStyle = EdgeInsets.symmetric(vertical: 14);

    if (_sending) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Wird gesendet …'),
        style: FilledButton.styleFrom(padding: buttonStyle),
      );
    }

    if (canChallenge) {
      return FilledButton.icon(
        onPressed: _challengeFriend,
        icon: const Icon(Icons.send),
        label: const Text('Freund herausfordern'),
        style: FilledButton.styleFrom(padding: buttonStyle),
      );
    }

    if (firebaseReady && isLoggedIn && !isVerified) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: userEmail ?? ''),
          ),
        ),
        icon: const Icon(Icons.mark_email_unread_outlined),
        label: const Text('Email bestätigen'),
        style: FilledButton.styleFrom(padding: buttonStyle),
      );
    }

    if (firebaseReady && !isLoggedIn) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        icon: const Icon(Icons.login),
        label: const Text('Anmelden für Herausforderung'),
        style: FilledButton.styleFrom(padding: buttonStyle),
      );
    }

    return FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.cloud_off_outlined),
      label: const Text('Login nicht verfügbar'),
      style: FilledButton.styleFrom(padding: buttonStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firebaseReady = FirebaseStatus.instance.isReady;
    final authUser =
        firebaseReady ? ref.watch(authStateProvider).value : null;
    final isLoggedIn = authUser != null;
    final isVerified = isLoggedIn && authUser.emailVerified;
    final canChallenge = firebaseReady && isVerified;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duell beendet'),
            Text(
              widget.lessonTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: TabletConstrained(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const SizedBox(height: 8),
              const Center(
                child: Text('🏁', style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 12),
              Text(
                'Gesamtzeit',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDuelTime(widget.result.totalMs),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.result.totalPenaltyMs > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'inkl. ${formatDuelTime(widget.result.totalPenaltyMs)} Strafzeit',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.result.roundsMs.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 16,
                          color: scheme.outlineVariant,
                        ),
                      _RoundRow(
                        index: i + 1,
                        ms: widget.result.roundsMs[i],
                        penaltyMs: widget.result.penaltiesMs[i],
                        format: formatDuelTime,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildPrimaryAction(
                context: context,
                firebaseReady: firebaseReady,
                isLoggedIn: isLoggedIn,
                isVerified: isVerified,
                canChallenge: canChallenge,
                userEmail: authUser?.email,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.replay),
                label: const Text('Andere Lektion'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
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
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Runde $index',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              format(ms),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (penaltyMs > 0)
              Text(
                '+${format(penaltyMs)} Strafe',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

