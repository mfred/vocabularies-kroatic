import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';

/// Helpers to deep-link into Android settings or Play Store listings.
///
/// On non-Android platforms these are no-ops.
class SystemIntents {
  const SystemIntents._();

  static Future<void> openTtsSettings() async {
    if (!Platform.isAndroid) return;
    const intent =
        AndroidIntent(action: 'com.android.settings.TTS_SETTINGS');
    await intent.launch();
  }

  static Future<void> openPackageLaunch(String packageId) async {
    if (!Platform.isAndroid) return;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: packageId,
      );
      await intent.launch();
    } catch (_) {
      await openPlayStorePackage(packageId);
    }
  }

  static Future<void> openAppInfo(String packageId) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$packageId',
    );
    await intent.launch();
  }

  static Future<void> openPlayStorePackage(String packageId) async {
    if (!Platform.isAndroid) return;
    final marketIntent = AndroidIntent(
      action: 'action_view',
      data: 'market://details?id=$packageId',
    );
    try {
      await marketIntent.launch();
    } catch (_) {
      final webIntent = AndroidIntent(
        action: 'action_view',
        data: 'https://play.google.com/store/apps/details?id=$packageId',
      );
      await webIntent.launch();
    }
  }
}
