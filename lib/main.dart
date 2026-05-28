import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/database.dart' hide StreakReward;
import 'features/streaks/services/reminder_service.dart';
import 'features/streaks/services/streak_service.dart';
import 'features/players/player_service.dart';
import 'firebase_options.dart';
import 'shared/firebase_status.dart';
import 'shared/providers.dart';

const Duration _kSplashMinHold = Duration(milliseconds: 1500);

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Splash bleibt sichtbar, bis wir ihn unten aktiv entfernen — sonst
  // verschwindet er, sobald der erste Frame rendert (~200 ms).
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final startedAt = DateTime.now();
  await _tryInitFirebase();
  // Eine einzige DB-Instanz für die gesamte App. Frueher öffnete der
  // Reminder-Init eine zweite Connection auf dieselbe Datei — beim Kaltstart
  // rannten beide gleichzeitig ins createAll()/Migration und kollidierten
  // mit "database is locked (code 5)".
  final db = AppDatabase();
  unawaited(_initReminderInBackground(db));
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const VocabulariesApp(),
    ),
  );
  final elapsed = DateTime.now().difference(startedAt);
  final remaining = _kSplashMinHold - elapsed;
  if (remaining > Duration.zero) {
    await Future<void>.delayed(remaining);
  }
  FlutterNativeSplash.remove();
}

/// Plant nach Kaltstart den Abend-Reminder neu. Nutzt die geteilte
/// AppDatabase-Instanz (kein eigenes close — die DB lebt für die App-Laufzeit).
/// Fehler werden geschluckt — der Reminder ist eine Komfortfunktion.
Future<void> _initReminderInBackground(AppDatabase db) async {
  try {
    final player = await PlayerService(db).ensureDefaultPlayer();
    final reminder = ReminderService(db, StreakService(db));
    await reminder.rescheduleReminder(player.id);
  } catch (_) {
    // Reminder ist nicht kritisch fürs App-Funktionieren.
  }
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
