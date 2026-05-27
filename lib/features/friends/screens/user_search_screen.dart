import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tablet_constrained.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../friends_providers.dart';
import '../models/user_profile.dart';

/// Zwei Such-Modi: Email und Anzeigename (Prefix).
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  UserSearchKind _kind = UserSearchKind.name;
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _hint {
    switch (_kind) {
      case UserSearchKind.email:
        return 'beispiel@mail.com';
      case UserSearchKind.name:
        return 'mind. 3 Zeichen';
    }
  }

  IconData get _icon {
    switch (_kind) {
      case UserSearchKind.email:
        return Icons.alternate_email;
      case UserSearchKind.name:
        return Icons.person_search_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSearch = _isValidQuery();

    return Scaffold(
      appBar: AppBar(title: const Text('Freund suchen')),
      body: SafeArea(
        child: TabletConstrained(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<UserSearchKind>(
                segments: const [
                  ButtonSegment(
                    value: UserSearchKind.name,
                    label: Text('Name'),
                    icon: Icon(Icons.person_search_outlined),
                  ),
                  ButtonSegment(
                    value: UserSearchKind.email,
                    label: Text('E-Mail'),
                    icon: Icon(Icons.alternate_email),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) {
                  setState(() {
                    _kind = s.first;
                    _query = '';
                    _controller.clear();
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  hintText: _hint,
                  prefixIcon: Icon(_icon),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: canSearch
                    ? _Results(kind: _kind, query: _normalizedQuery())
                    : Center(
                        child: Text(
                          'Tippe einen Suchbegriff ein.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  bool _isValidQuery() {
    final q = _query.trim();
    switch (_kind) {
      case UserSearchKind.email:
        return q.contains('@') && q.length > 3;
      case UserSearchKind.name:
        return q.length >= 3;
    }
  }

  String _normalizedQuery() {
    final q = _query.trim().toLowerCase();
    return q;
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.kind, required this.query});

  final UserSearchKind kind;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(myUserProfileProvider).value;
    final async = ref.watch(
      searchUsersProvider((kind: kind, query: query)),
    );
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            e is TimeoutException
                ? 'Suche dauerte zu lange. Bist du online?'
                : 'Fehler: $e',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
      data: (results) {
        final filtered =
            results.where((p) => me == null || p.uid != me.uid).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Niemanden gefunden.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Der gesuchte Account muss eingeloggt sein und seine Email bestätigt haben.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          itemBuilder: (context, i) => _ResultTile(profile: filtered[i]),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: filtered.length,
        );
      },
    );
  }
}

class _ResultTile extends ConsumerStatefulWidget {
  const _ResultTile({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ResultTile> createState() => _ResultTileState();
}

class _ResultTileState extends ConsumerState<_ResultTile> {
  bool _sending = false;
  String? _info;

  Future<void> _send() async {
    final me = ref.read(myUserProfileProvider).value;
    if (me == null) return;
    setState(() {
      _sending = true;
      _info = null;
    });
    try {
      await ref.read(friendServiceProvider).sendRequest(
            fromUid: me.uid,
            fromDisplayName: me.displayName,
            toUid: widget.profile.uid,
          );
      if (!mounted) return;
      setState(() => _info = 'Anfrage gesendet');
    } catch (e) {
      if (!mounted) return;
      setState(() => _info = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          UserAvatar(
            seed: widget.profile.uid,
            style: widget.profile.avatarStyle ?? 'lorelei',
            fallbackText: widget.profile.displayName,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_info != null)
                  Text(
                    _info!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt),
            label: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }
}
