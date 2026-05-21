import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'shared/firebase_status.dart';

const Duration _kSplashMinHold = Duration(milliseconds: 1500);

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Splash bleibt sichtbar, bis wir ihn unten aktiv entfernen — sonst
  // verschwindet er, sobald der erste Frame rendert (~200 ms).
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final startedAt = DateTime.now();
  await _tryInitFirebase();
  runApp(const ProviderScope(child: VocabulariesApp()));
  final elapsed = DateTime.now().difference(startedAt);
  final remaining = _kSplashMinHold - elapsed;
  if (remaining > Duration.zero) {
    await Future<void>.delayed(remaining);
  }
  FlutterNativeSplash.remove();
}

Future<void> _tryInitFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseStatus.instance.markReady();
  } catch (e, st) {
    FirebaseStatus.instance.markUnavailable(e.toString());
    // ignore: avoid_print
    print('[Firebase init failed] $e\n$st');
    if (kDebugMode) {
      debugPrint(
        'Firebase nicht initialisiert ($e). '
        'Login + Global-Highscore deaktiviert. '
        'Lauf `flutterfire configure`, um sie zu aktivieren.',
      );
    }
  }
}
