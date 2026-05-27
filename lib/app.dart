import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/database.dart' hide StreakReward;
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/auth/screens/verify_email_screen.dart';
import 'features/duel/duel_providers.dart';
import 'features/friends/friends_providers.dart';
import 'features/friends/screens/friends_screen.dart';
import 'features/highscore/screens/highscore_screen.dart';
import 'features/lessons/lesson_menu_screen.dart';
import 'features/quiz/models/quiz_direction.dart';
import 'features/quiz/models/quiz_format.dart';
import 'features/quiz/screens/quiz_screen.dart';
import 'features/quiz/services/daily_quiz_builder.dart';
import 'features/streaks/models/streak_reward.dart';
import 'shared/app_info.dart';
import 'shared/firebase_status.dart';
import 'shared/providers.dart';

const Map<String, IconData> _topicIcons = {
  'greetings': Icons.waving_hand,
  'introduction': Icons.person_outline,
  'numbers-time': Icons.schedule,
  'family': Icons.diversity_3,
  'shopping': Icons.shopping_basket_outlined,
  'restaurant': Icons.restaurant,
  'traffic': Icons.directions_bus_filled_outlined,
  'tourism': Icons.beach_access,
  'advanced': Icons.psychology_outlined,
};

IconData _iconFor(String lessonId) =>
    _topicIcons[lessonId] ?? Icons.menu_book_outlined;

class VocabulariesApp extends StatelessWidget {
  const VocabulariesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vokabeltrainer',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const SyncStatusScreen(),
    );
  }
}

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(cachedLessonsProvider);
    final syncAsync = ref.watch(syncResultProvider);

    final direction = ref.watch(preferredDirectionProvider);
    final isDeHr = direction == QuizDirection.deToHr;
    final flagDisplay = isDeHr ? '🇩🇪 → 🇭🇷' : '🇭🇷 → 🇩🇪';
    final streak = ref.watch(currentStreakProvider).value ?? 0;

    ref.listen<AsyncValue<StreakReward?>>(streakRewardCheckProvider,
        (prev, next) {
      final reward = next.value;
      if (reward == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showStreakRewardDialog(context, reward);
      });
    });

    // Sicherstellen, dass nach Login das Firestore-Profil existiert.
    ref.watch(ensureProfileOnLoginProvider);

    return Scaffold(
      drawer: const _AppDrawer(),
      appBar: AppBar(
        leading: Consumer(builder: (context, ref, _) {
          final count =
              ref.watch(incomingFriendRequestsProvider).value?.length ?? 0;
          final icon = Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Menü öffnen',
            ),
          );
          if (count == 0) return icon;
          return Badge.count(
            count: count,
            alignment: const AlignmentDirectional(0.85, 0.15),
            child: icon,
          );
        }),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vokabeltrainer'),
            const SizedBox(width: 10),
            InkWell(
              onTap: () =>
                  ref.read(preferredDirectionProvider.notifier).toggle(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(flagDisplay,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
        bottom: streak > 0 ? _StreakBanner(streak: streak) : null,
      ),
      body: lessonsAsync.when(
        loading: () => const _LoadingView(),
        error: (err, _) => _ErrorView(
          error: err.toString(),
          onRetry: () => ref.invalidate(syncResultProvider),
        ),
        data: (lessons) {
          final result = syncAsync.value;
          return _LessonOverview(lessons: lessons, syncResult: result);
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Lade Vokabeln …'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Fehler beim Laden',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Nochmal versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonOverview extends ConsumerWidget {
  const _LessonOverview({required this.lessons, this.syncResult});

  final List<dynamic> lessons;
  final dynamic syncResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalItems = lessons.fold<int>(
      0,
      (sum, l) =>
          sum + ((l.wordCount + l.phraseCount + l.sentenceCount) as int),
    );
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(syncResultProvider);
        await ref.read(cachedLessonsProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child:
                _SyncBanner(syncResult: syncResult, totalItems: totalItems),
          ),
          if (lessons.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(syncResult: syncResult),
            )
          else ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: _DailyChallengeCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverList.builder(
                itemCount: lessons.length,
                itemBuilder: (context, index) =>
                    _TopicCard(lesson: lessons[index]),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.syncResult});

  final dynamic syncResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = syncResult?.error as String?;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            error == null ? Icons.inbox_outlined : Icons.cloud_off,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            error == null
                ? 'Noch keine Lektionen geladen'
                : 'Daten konnten nicht geladen werden',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (error != null) ...[
            Text(
              error,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Nach unten ziehen, um neu zu synchronisieren.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatefulWidget {
  const _SyncBanner({required this.syncResult, required this.totalItems});

  final dynamic syncResult;
  final int totalItems;

  @override
  State<_SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<_SyncBanner> {
  bool _hidden = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _SyncBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncResult != widget.syncResult) {
      setState(() => _hidden = false);
      _scheduleHide();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _timer?.cancel();
    final hasError = widget.syncResult?.error != null;
    final isFromCache = widget.syncResult?.fromCache == true;
    if (hasError || isFromCache) return;
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hidden = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _hidden ? const SizedBox.shrink() : _buildBanner(context),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isFromCache = widget.syncResult?.fromCache == true;
    final hasError = widget.syncResult?.error != null;
    final color = hasError
        ? theme.colorScheme.errorContainer
        : isFromCache
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.primaryContainer;
    final fg = hasError
        ? theme.colorScheme.onErrorContainer
        : isFromCache
            ? theme.colorScheme.onTertiaryContainer
            : theme.colorScheme.onPrimaryContainer;
    final label = hasError
        ? 'Offline — Cache wird angezeigt'
        : isFromCache
            ? 'Offline — letzter Sync wird verwendet'
            : 'Aktuell — frisch synchronisiert';
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError
                    ? Icons.cloud_off
                    : isFromCache
                        ? Icons.cached
                        : Icons.cloud_done,
                color: fg,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: TextStyle(color: fg))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.totalItems} Vokabeln in ${widget.syncResult?.lessonsTotal ?? 0} Lektionen',
            style: theme.textTheme.titleMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _DailyChallengeCard extends ConsumerWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(dailyChallengeTodayProvider);
    final direction = ref.watch(preferredDirectionProvider);

    return today.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (entry) {
        final done = entry != null;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: done
              ? scheme.surfaceContainerHighest
              : scheme.tertiaryContainer.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              width: 1.5,
              color: done ? scheme.outlineVariant : scheme.tertiary,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: done
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          lessonId: kDailyLessonId,
                          lessonTitle: 'Quiz des Tages',
                          direction: direction,
                          format: QuizFormat.multipleChoice,
                          dailyMode: true,
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Text(
                    done ? '✅' : '⭐',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quiz des Tages',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          done
                              ? '${entry.scorePoints} P · ${entry.correctCount}/${entry.totalCount} — morgen wieder'
                              : '10 Fragen — gleiche für alle Spieler',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!done)
                    Icon(Icons.play_arrow, color: scheme.tertiary, size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopicCard extends ConsumerWidget {
  const _TopicCard({required this.lesson});

  final LessonsCacheData lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final icon = _iconFor(lesson.lessonId);
    final incomingCount = ref.watch(incomingPendingDuelsProvider).maybeWhen(
          data: (duels) =>
              duels.where((d) => d.lessonId == lesson.lessonId).length,
          orElse: () => 0,
        );
    final progress = ref.watch(lessonProgressProvider).maybeWhen(
          data: (m) => m[lesson.lessonId] ?? 0.0,
          orElse: () => 0.0,
        );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          width: 1.5,
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonMenuScreen(lesson: lesson),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Icon(icon, size: 44, color: theme.colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.titleDe,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: theme
                                  .colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progress * 100).round()} %',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (incomingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt,
                            size: 14, color: theme.colorScheme.onTertiary),
                        const SizedBox(width: 2),
                        Text(
                          '$incomingCount',
                          style: TextStyle(
                            color: theme.colorScheme.onTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firebaseReady = FirebaseStatus.instance.isReady;
    final authUser =
        firebaseReady ? ref.watch(authStateProvider).value : null;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vokabeltrainer',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('🇩🇪 ↔ 🇭🇷', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Lektionen'),
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Bestenliste'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HighscoreScreen(),
                  ),
                );
              },
            ),
            if (firebaseReady && authUser != null && authUser.emailVerified)
              _FriendsDrawerEntry()
            else if (firebaseReady && authUser != null && !authUser.emailVerified)
              ListTile(
                enabled: false,
                leading: const Icon(Icons.group_outlined),
                title: const Text('Freunde'),
                subtitle: const Text('Bitte zuerst Email bestätigen'),
              )
            else if (firebaseReady)
              ListTile(
                enabled: false,
                leading: const Icon(Icons.group_outlined),
                title: const Text('Freunde'),
                subtitle: const Text('Anmelden, um Freunde hinzuzufügen'),
              ),
            if (firebaseReady)
              ListTile(
                leading: Icon(authUser == null
                    ? Icons.login
                    : (authUser.emailVerified
                        ? Icons.account_circle_outlined
                        : Icons.mark_email_unread_outlined)),
                title: Text(
                  authUser == null
                      ? 'Anmelden / Registrieren'
                      : (authUser.emailVerified
                          ? 'Mein Profil'
                          : 'Email bestätigen'),
                ),
                subtitle: authUser?.email != null
                    ? Text(
                        authUser!.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) {
                        if (authUser == null) return const LoginScreen();
                        if (!authUser.emailVerified) {
                          return VerifyEmailScreen(
                              email: authUser.email ?? '');
                        }
                        return const ProfileScreen();
                      },
                    ),
                  );
                },
              )
            else
              ListTile(
                enabled: false,
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Login nicht verfügbar'),
                subtitle: Text(
                  FirebaseStatus.instance.error ??
                      'Firebase nicht initialisiert',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Über die App'),
              onTap: () {
                Navigator.of(context).pop();
                showAboutDialog(
                  context: context,
                  applicationName: kAppName,
                  applicationIcon: const Text(
                    '🇩🇪',
                    style: TextStyle(fontSize: 32),
                  ),
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Version $kAppVersionDisplay',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(kAppTagline),
                    const SizedBox(height: 12),
                    const Text(
                      'Vokabeltrainer für Deutsch und Kroatisch — '
                      'mit Quiz, Lautschrift, Hör- und Sprechübungen.',
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deutsch ↔ Kroatisch',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'v$kAppVersionDisplay',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsDrawerEntry extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingCount =
        ref.watch(incomingFriendRequestsProvider).value?.length ?? 0;
    return ListTile(
      leading: const Icon(Icons.group_outlined),
      title: const Text('Freunde'),
      trailing: incomingCount > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$incomingCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const FriendsScreen(),
          ),
        );
      },
    );
  }
}

class _StreakBanner extends StatelessWidget implements PreferredSizeWidget {
  const _StreakBanner({required this.streak});

  final int streak;

  static const double _height = 32;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: _height,
      width: double.infinity,
      color: scheme.tertiaryContainer,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '$streak Tag${streak == 1 ? '' : 'e'} in Folge',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

void _showStreakRewardDialog(BuildContext context, StreakReward reward) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      if (reward.streakDay == 7) {
        // Sondervariante: dreiteiliges Geschenk (Bonus + Saver + Doppel-Punkte).
        return AlertDialog(
          icon: const Text('🎉🔥🎁', style: TextStyle(fontSize: 36)),
          title: const Text('Eine Woche durchgehalten!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sieben Tage in Folge gespielt — du bekommst gleich drei '
                'Geschenke obendrauf:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _GiftLine(emoji: '💰', text: '+${reward.bonusPoints} Bonuspunkte für dein nächstes Quiz'),
              const SizedBox(height: 4),
              _GiftLine(emoji: '🛡️', text: '1× Streak-Schoner — verpass einen Tag, ohne dass dein Streak bricht'),
              const SizedBox(height: 4),
              _GiftLine(emoji: '✖️2️⃣', text: 'Doppel-Punkte-Boost: nächstes Quiz zählt ×2'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Weiter rocken!'),
            ),
          ],
        );
      }
      return AlertDialog(
        icon: const Text('🎉', style: TextStyle(fontSize: 40)),
        title: Text('Tag ${reward.streakDay} erreicht!'),
        content: Text(
          '+${reward.bonusPoints} Bonuspunkte für deinen nächsten Quiz.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stark!'),
          ),
        ],
      );
    },
  );
}

class _GiftLine extends StatelessWidget {
  const _GiftLine({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
