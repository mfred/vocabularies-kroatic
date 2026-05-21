import 'package:flutter/material.dart';

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
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Text(
              _initial(request.fromDisplayName),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
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

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }
}
