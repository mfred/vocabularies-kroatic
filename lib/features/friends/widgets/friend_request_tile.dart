import 'package:flutter/material.dart';

import '../../../shared/widgets/user_avatar.dart';
import '../models/friend_request.dart';

/// Ein eingehender oder ausgehender Anfrage-Eintrag.
class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.request,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final FriendRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  bool get _isIncoming => onAccept != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: scheme.surface,
      ),
      child: Row(
        children: [
          UserAvatar(
            // Incoming: vom Sender (fromUid). Outgoing: zum Empfänger (toUid).
            seed: _isIncoming ? request.fromUid : request.toUid,
            fallbackText: request.fromDisplayName,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromDisplayName.isEmpty
                      ? 'Unbekannt'
                      : request.fromDisplayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isIncoming
                      ? 'möchte mit dir befreundet sein'
                      : 'Anfrage gesendet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isIncoming) ...[
            IconButton.filledTonal(
              onPressed: onDecline,
              icon: const Icon(Icons.close),
              tooltip: 'Ablehnen',
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: onAccept,
              icon: const Icon(Icons.check),
              tooltip: 'Annehmen',
            ),
          ] else
            TextButton(
              onPressed: onCancel,
              child: const Text('Zurückziehen'),
            ),
        ],
      ),
    );
  }
}
