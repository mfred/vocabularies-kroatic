import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared/providers.dart';

class VocabulariesApp extends StatelessWidget {
  const VocabulariesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vokabeltrainer DE↔HR',
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
      appBar: AppBar(
        title: const Text('Vokabeltrainer DE ↔ HR'),
        actions: [
          IconButton(
            tooltip: 'Erneut synchronisieren',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(syncResultProvider);
            },
          ),
        ],
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
          SliverList.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return _LessonTile(lesson: lesson);
            },
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

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.syncResult, required this.totalItems});

  final dynamic syncResult;
  final int totalItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFromCache = syncResult?.fromCache == true;
    final hasError = syncResult?.error != null;
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
              Expanded(
                child: Text(label, style: TextStyle(color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$totalItems Vokabeln in ${syncResult?.lessonsTotal ?? 0} Lektionen',
            style: theme.textTheme.titleMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final dynamic lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = lesson.wordCount + lesson.phraseCount + lesson.sentenceCount;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: Text('${lesson.orderIndex}'),
      ),
      title: Text(lesson.titleDe),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson.titleHr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              )),
          const SizedBox(height: 4),
          Text(
            '$total Items  •  ${lesson.wordCount}W / ${lesson.phraseCount}P / ${lesson.sentenceCount}S  •  Diff ${lesson.difficulty}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Text('v${lesson.version}',
          style: theme.textTheme.bodySmall),
    );
  }
}
