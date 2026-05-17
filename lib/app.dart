import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/database.dart';
import 'features/highscore/screens/highscore_screen.dart';
import 'features/lessons/lesson_detail_screen.dart';
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

    return Scaffold(
      drawer: const _AppDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Vokabeltrainer'),
            SizedBox(width: 10),
            Text('🇩🇪 ↔ 🇭🇷', style: TextStyle(fontSize: 20)),
          ],
        ),
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

class _LessonOverview extends StatelessWidget {
  const _LessonOverview({required this.lessons, this.syncResult});

  final List<dynamic> lessons;
  final dynamic syncResult;

  @override
  Widget build(BuildContext context) {
    final totalItems = lessons.fold<int>(
      0,
      (sum, l) =>
          sum + ((l.wordCount + l.phraseCount + l.sentenceCount) as int),
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SyncBanner(syncResult: syncResult, totalItems: totalItems),
        ),
        if (lessons.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(syncResult: syncResult),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverList.builder(
              itemCount: lessons.length,
              itemBuilder: (context, index) =>
                  _TopicCard(lesson: lessons[index]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
            'Status oben prüfen, dann Refresh-Knopf in der Titelzeile.',
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

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.lesson});

  final LessonsCacheData lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconFor(lesson.lessonId);
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
              builder: (_) => LessonDetailScreen(lesson: lesson),
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
                child: Text(
                  lesson.titleDe,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
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

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Deutsch ↔ Kroatisch',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
