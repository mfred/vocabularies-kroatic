import 'package:flutter/material.dart';

import '../services/system_intents.dart';

Future<void> showMissingTtsLanguageDialog(
  BuildContext context,
  String langTag,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Sprachausgabe fehlt'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _ttsContent(theme, langTag, ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schließen'),
          ),
          TextButton(
            onPressed: () =>
                SystemIntents.openPlayStorePackage('com.google.android.tts'),
            child: const Text('Im Play Store'),
          ),
        ],
      );
    },
  );
}

List<Widget> _ttsContent(
  ThemeData theme,
  String langTag,
  BuildContext ctx,
) {
  return [
    Text(
      'Die Stimme für $langTag ist auf diesem Gerät nicht installiert.',
      style: theme.textTheme.bodyMedium,
    ),
    const SizedBox(height: 12),
    Text(
      'So ergänzt du sie:',
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 6),
    const _Step(n: 1, text: '„Sprachdienste öffnen" antippen'),
    const _Step(
      n: 2,
      text: '„Bevorzugte Engine" → Speech Services by Google',
    ),
    const _Step(
      n: 3,
      text: 'Zahnrad daneben → „Sprachen" → '
          'Kroatisch (Hrvatski) herunterladen',
    ),
    const SizedBox(height: 14),
    _ActionButton(
      icon: Icons.settings_voice,
      label: 'Sprachdienste öffnen',
      onTap: () async {
        await SystemIntents.openTtsSettings();
        if (ctx.mounted) Navigator.of(ctx).pop();
      },
    ),
    const SizedBox(height: 8),
    _ActionButton(
      icon: Icons.info_outline,
      label: 'App-Info: Google TTS',
      filled: false,
      onTap: () async {
        await SystemIntents.openAppInfo('com.google.android.tts');
        if (ctx.mounted) Navigator.of(ctx).pop();
      },
    ),
  ];
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$n.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}
