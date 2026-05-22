import 'package:flutter/material.dart';

import '../../../shared/widgets/user_avatar.dart';
import '../models/user_profile.dart';

class FriendListTile extends StatelessWidget {
  const FriendListTile({
    super.key,
    required this.profile,
    this.onRemove,
  });

  final UserProfile profile;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: scheme.surface,
      ),
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
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.person_remove_outlined, color: scheme.outline),
              tooltip: 'Entfernen',
            ),
        ],
      ),
    );
  }

}
