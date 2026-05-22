import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/user_avatar.dart';
import '../../friends/friends_providers.dart';
import '../../friends/models/user_profile.dart';
import '../../friends/screens/user_search_screen.dart';

/// Modal: zeigt die Freundesliste; gibt das ausgewählte [UserProfile] über
/// `Navigator.pop(profile)` zurück. Bei Abbruch / leerer Liste null.
class DuelFriendPickerDialog extends ConsumerWidget {
  const DuelFriendPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final friends = ref.watch(friendsListProvider);
    return AlertDialog(
      title: const Text('Wen herausfordern?'),
      content: SizedBox(
        width: double.maxFinite,
        child: friends.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Fehler: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off_outlined,
                        size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 8),
                    Text(
                      'Noch keine Freunde.\n'
                      'Füg jemanden hinzu, um ihn herauszufordern.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UserSearchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Freund hinzufügen'),
                    ),
                  ],
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return _FriendRow(
                    profile: p,
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              UserAvatar(
                seed: profile.uid,
                style: profile.avatarStyle ?? 'lorelei',
                fallbackText: profile.displayName,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.send, color: scheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
