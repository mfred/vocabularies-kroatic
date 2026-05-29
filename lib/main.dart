import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app.dart';
import 'core/database/database.dart' hide StreakReward;
import 'features/streaks/services/reminder_service.dart';
import 'features/streaks/services/streak_service.dart';
import 'features/players/player_service.dart';
import 'firebase_options.dart';
import 'shared/firebase_status.dart';
import 'shared/providers.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Native Splash (nur grüner Hintergrund) halten, bis Flutter den ersten
  // Frame zeichnet. Das Logo zeigt danach der Flutter-Splash (SplashGate) —
  // das native Splash-Icon rendert auf manchen Emulatoren (MEMU) nicht
  // zuverlässig, v.a. im Querformat.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  // Avatar-SVGs (DiceBear) liegen in flutter_svgs prozessweitem LRU-Cache. Cap
  // anheben, damit große Bestenlisten/Suchen (>100 distinkte Avatare über alle
  // Range-Tabs) nicht innerhalb der Session verdrängt und neu geladen werden.
  svg.cache.maximumSize = 256;
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
  } catch (e) {
    FirebaseStatus.instance.markUnavailable(e.toString());
    if (kDebugMode) {
      debugPrint(
        'Firebase nicht initialisiert ($e). '
        'Login + Global-Highscore deaktiviert. '
        'Lauf `flutterfire configure`, um sie zu aktivieren.',
      );
    }
  }
}
