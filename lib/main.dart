import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'shared/firebase_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _tryInitFirebase();
  runApp(const ProviderScope(child: VocabulariesApp()));
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
