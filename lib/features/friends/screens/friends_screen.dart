import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../friends_providers.dart';
import '../models/friend_request.dart';
import '../models/user_profile.dart';
import '../widgets/friend_list_tile.dart';
import '../widgets/friend_request_tile.dart';
import 'user_search_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).value;
    if (auth == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Freunde')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bitte zuerst anmelden, um Freunde hinzuzufügen.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final incomingCount =
        ref.watch(incomingFriendRequestsProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freunde'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            const Tab(text: 'Freunde'),
            Tab(
              text: incomingCount == 0
                  ? 'Anfragen'
                  : 'Anfragen ($incomingCount)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _FriendsListTab(),
          _RequestsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UserSearchScreen()),
        ),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Hinzufügen'),
      ),
    );
  }
}

class _FriendsListTab extends ConsumerWidget {
  const _FriendsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncFriends = ref.watch(friendsListProvider);
    return asyncFriends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(error: e),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined,
                      size: 56, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    'Noch keine Freunde.\nNutze den + Button, um jemanden hinzuzufügen.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemBuilder: (context, i) => _FriendRow(profile: friends[i]),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemCount: friends.length,
        );
      },
    );
  }
}

class _FriendRow extends ConsumerWidget {
  const _FriendRow({required this.profile});

  final UserProfile profile;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Freund entfernen?'),
        content: Text(
            '${profile.displayName} aus deiner Freundesliste entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final me = ref.read(myUserProfileProvider).value;
    if (me == null) return;
    await ref.read(friendServiceProvider).removeFriend(me.uid, profile.uid);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FriendListTile(
      profile: profile,
      onRemove: () => _confirmRemove(context, ref),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final incoming = ref.watch(incomingFriendRequestsProvider);
    final outgoing = ref.watch(outgoingFriendRequestsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'Eingehend',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        incoming.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Fehler: $e'),
          data: (list) {
            if (list.isEmpty) {
              return _EmptyHint(
                  text: 'Keine offenen Anfragen.',
                  icon: Icons.inbox_outlined);
            }
            return Column(
              children: [
                for (final r in list) ...[
                  _IncomingRow(request: r),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Ausgehend',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        outgoing.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Fehler: $e'),
          data: (list) {
            if (list.isEmpty) {
              return _EmptyHint(
                  text: 'Keine wartenden Anfragen.',
                  icon: Icons.outbox_outlined);
            }
            return Column(
              children: [
                for (final r in list) ...[
                  _OutgoingRow(request: r),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IncomingRow extends ConsumerWidget {
  const _IncomingRow({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FriendRequestTile(
      request: request,
      onAccept: () async {
        final me = ref.read(myUserProfileProvider).value;
        if (me == null) return;
        try {
          await ref
              .read(friendServiceProvider)
              .acceptRequest(request, me: me);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      },
      onDecline: () async {
        try {
          await ref.read(friendServiceProvider).declineRequest(request);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      },
    );
  }
}

class _OutgoingRow extends ConsumerWidget {
  const _OutgoingRow({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FriendRequestTile(
      request: request,
      onCancel: () async {
        try {
          await ref.read(friendServiceProvider).cancelRequest(request);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});

  final Object error;

  bool get _isPermissionDenied {
    final e = error;
    if (e is FirebaseException) {
      return e.code == 'permission-denied';
    }
    return e.toString().contains('permission-denied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final headline = _isPermissionDenied
        ? 'Freundesliste vorübergehend nicht erreichbar'
        : 'Fehler beim Laden';
    final detail = _isPermissionDenied
        ? 'Die Firestore-Regeln werden gerade aktualisiert. Probier es in einer Minute erneut.'
        : error.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(headline,
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
