import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tablet_constrained.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../friends/friends_providers.dart';

/// Modal-Sheet zur Auswahl des DiceBear-Avatar-Stils. Zeigt für jeden
/// verfügbaren Stil eine Live-Vorschau (mit derselben UID-Seed) und schreibt
/// die Auswahl in `users/{uid}.avatarStyle`.
class AvatarPickerSheet extends ConsumerStatefulWidget {
  const AvatarPickerSheet({
    super.key,
    required this.uid,
    required this.currentStyle,
  });

  final String uid;
  final String currentStyle;

  @override
  ConsumerState<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends ConsumerState<AvatarPickerSheet> {
  String? _savingStyle;
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStyle;
  }

  Future<void> _select(String style) async {
    if (_savingStyle != null || style == _selected) return;
    setState(() => _savingStyle = style);
    try {
      await ref
          .read(userProfileServiceProvider)
          .updateAvatarStyle(widget.uid, style);
      if (!mounted) return;
      setState(() {
        _selected = style;
        _savingStyle = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar-Stil aktualisiert.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingStyle = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: TabletConstrained(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Avatar-Stil wählen',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tippe auf einen Stil — der Avatar wird sofort aktualisiert.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: kDiceBearStyles.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, i) {
                    final style = kDiceBearStyles[i];
                    final isCurrent = style == _selected;
                    final isSaving = _savingStyle == style;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : () => _select(style),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: isCurrent ? 2 : 1,
                          ),
                          color: isCurrent
                              ? scheme.primaryContainer.withValues(alpha: 0.25)
                              : scheme.surface,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                UserAvatar(
                                  seed: widget.uid,
                                  style: style,
                                  size: 64,
                                ),
                                if (isSaving)
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              style,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
