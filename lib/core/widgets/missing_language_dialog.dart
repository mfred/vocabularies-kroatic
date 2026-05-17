import 'package:flutter/material.dart';

import '../services/system_intents.dart';

enum LanguageFeature { tts, stt }

Future<void> showMissingLanguageDialog(
  BuildContext context,
  LanguageFeature feature,
  String langTag,
) {
  final isTts = feature == LanguageFeature.tts;
  final title = isTts ? 'Sprachausgabe fehlt' : 'Spracherkennung fehlt';
  final body = isTts
      ? 'Die Stimme für $langTag ist auf diesem Gerät nicht installiert. '
          'Du kannst sie in den System-Sprachdiensten nachladen oder '
          'die Google-Sprachdienste-App im Play Store öffnen.'
      : 'Das Offline-Sprachpaket für $langTag ist nicht installiert. '
          'Lade das Paket in den Spracheinstellungen herunter oder '
          'öffne die Google-App im Play Store.';
  final pkg = isTts
      ? 'com.google.android.tts'
      : 'com.google.android.googlequicksearchbox';

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schließen'),
          ),
          TextButton(
            onPressed: () async {
              await SystemIntents.openPlayStorePackage(pkg);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Im Play Store'),
          ),
          FilledButton(
            onPressed: () async {
              if (isTts) {
                await SystemIntents.openTtsSettings();
              } else {
                await SystemIntents.openVoiceInputSettings();
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(
              isTts
                  ? 'Sprachdienste öffnen'
                  : 'Spracheinstellungen öffnen',
            ),
          ),
        ],
      );
    },
  );
}
