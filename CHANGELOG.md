# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Added — Iteration 39 (Quiz des Tages)
- **Tägliche Challenge** auf dem Home-Screen direkt über den Lektions-Karten:
  10 Multiple-Choice-Fragen aus dem Gesamt-Pool (alle Lektionen), Seed =
  heutiger Datumsschlüssel `YYYYMMDD`. Alle Spieler bekommen am selben Tag
  dieselben Items und Distractoren — direkter Vergleich auf der globalen
  Bestenliste.
- **Genau ein Versuch pro Tag, pro Spieler**: neue Drift-Tabelle
  `daily_challenges` (Migration v6 → v7) speichert Score + Counts pro
  `(date_key, player_id)`. Nach Abschluss zeigt die Karte das Ergebnis und
  ist bis Mitternacht gesperrt.
- **Neue Komponenten**: `lib/features/quiz/services/daily_quiz_builder.dart`,
  `_DailyChallengeCard` in `lib/app.dart`, `dailyChallengeTodayProvider` in
  `shared/providers.dart`. `QuizSessionArgs` bekommt eine `dailyMode`-Flag,
  `QuizScreen` reicht sie durch, `QuizSessionController` wählt darauf den
  Daily-Builder + speichert nach `_finish` die `DailyChallenge`-Zeile.
- **Tests**: `daily_quiz_builder_test.dart` deckt Determinismus pro Datum,
  Unterschied zwischen zwei Tagen und Datumsschlüssel-Kodierung ab.
- **Sentinel-Lesson-ID** `__daily__` für Daily-Sessions — taucht in der
  Bestenliste als normale Punktebeitrag des Spielers auf; Detail-Joins auf
  `lessons_cache` ergeben leer und werden vom existierenden left-outer-Join
  toleriert.

### Changed — Iteration 38 (Joker-Wertigkeiten an Skala x20 angeglichen)
- **Joker-Kosten** in `JokerType` deutlich angehoben, damit Joker bei der
  seit Iteration 21 geltenden Score-Skala (Max ~80 P pro Quiz) wieder eine
  strategische Ressource sind:
  - **Lautschrift** 2 → **10 P**
  - **50/50** 1 → **5 P**
  - **Vorlesen** 1 → **10 P**
- `score_explanation_dialog`: Bullet-Texte und Beispiel auf die neuen
  Kosten umgestellt (Beispiel mit 2× IPA + 1× 50/50 jetzt 33 P statt 53 P).
- Joker-Score-Tests rechnen mit den neuen Cost-Werten (2× IPA = −20,
  gemischt 2×10 + 5 + 10 = 35). `computeScore` selbst unverändert.

### Changed — Iteration 25 (Duell pro Kategorie, Countdown blickdicht, Freunde-UX)
- **Duell vom Top-Level entfernt**: keine eigene Karte mehr auf dem Home
  und kein `DuelHomeScreen`-Hub. Stattdessen ist „Duell" jetzt die vierte
  Aktion in jedem `LessonMenuScreen` (parallel zu Quiz / Vokabeln lernen /
  Fehler ausbessern), deaktiviert bei < 12 Vokabeln.
- **Eingehende Herausforderungen pro Lektion**: kleine Pille (⚡+Anzahl)
  auf jeder `_TopicCard` im Home zeigt, in welcher Kategorie etwas
  wartet. Im `LessonMenuScreen` werden die Duelle dieser Lektion in
  einer eigenen Sektion oben angezeigt und können dort angenommen
  werden. `IncomingDuelTile` als wiederverwendbares Widget extrahiert.
- **Duell-Start zentralisiert** in `duel_launcher.dart`
  (`startDuelForLesson`), nutzt weiter `DuelSetBuilder` + globale
  `preferredDirectionProvider`.
- **Countdown-Overlay blickdicht**: war vorher
  `Colors.black.withValues(alpha: 0.55)` — Vokabel-Karten haben durch
  den halbtransparenten Layer durchgeschimmert. Jetzt
  `theme.colorScheme.surface` (alpha 1.0), passt zum App-Theme.

### Fixed — Iteration 25 (Freundesliste)
- **`friendsListProvider`** yieldet sofort `[]`, statt im Loading-State
  zu hängen, falls der Firestore-Stream verzögert antwortet (etwa
  während die Auth-Session noch initialisiert wird).
- **Permission-Denied-Fehler im `FriendsScreen`** wird jetzt mit
  klarer Erklärung („Firestore-Regeln werden gerade aktualisiert")
  statt mit roher Exception angezeigt. **Root-Cause-Fix** liegt
  außerhalb des Codes: `firebase deploy --only firestore:rules,firestore:indexes`
  nach dem Push ausführen — die Rule für `friendships` existiert lokal
  (Iteration 23), war aber serverseitig nicht aktiv.

### Changed — Iteration 25 (Freund-Code UI)
- `user_search_screen.dart`: Hint im Code-Modus präziser
  („Freund-Code (6 Zeichen, z. B. AB3K9X)"), `helperText` erklärt
  Herkunft des Codes. Eigener Code-Banner sagt jetzt: „gib ihn deinem
  Freund weiter".

### Changed — Iteration 25 (Duell-Strafzeit)
- `kDuelPenaltyMs` von 200 ms → 500 ms — falsche Zuordnung kostet
  jetzt deutlich mehr Zeit. Snippet in der `_IntroBox` wurde mit dem
  alten `DuelHomeScreen` ohnehin entfernt; falls der Hinweis irgendwo
  in der App wieder auftaucht, dort von „0,2 s" auf „0,5 s" anpassen.

### Changed — Iteration 21 (Score-Skala x20 + Streak-Geschenk + Reset)
- **`computeScore` skaliert um Faktor 20**: Treffer × 100 → × 5,
  Zeitbonus max 600 → 30 (halbiert sich alle 20 s). Maximum pro Quiz
  jetzt ~80 P statt ~1 600 P.
- **Joker-Kosten angepasst**: IPA 15 → 2, 50/50 5 → 1, Vorlesen 8 → 1.
- **Streak-Reward-Tiers neu**: 3→3, **7→50** (saftiger 7-Tage-Bonus),
  14→30, 30→100, 60→200, 100→500.
- **Lokaler Highscore-Reset** in Drift-Migration v5 → v6: alle
  `quiz_sessions.score_points` und `pending_bonus_points` auf 0,
  Streak-Reward-Claims gelöscht. Cloud-Leaderboard (Firestore) muss
  der User manuell zurücksetzen — Aggregat mischt sich sonst
  temporär, bis genug neue Sessions hochgeladen sind.
- Score-Erklärungs-Dialog mit neuer Skala + neuem Beispiel.

### Added — Iteration 21 (7-Tage-Streak-Geschenk, dreiteilig)
- **Saftige Bonuspunkte**: 7-Tage-Stufe gibt 50 P (~ein ganzes Quiz wert).
- **Streak-Schoner**: ein verpasster Tag wird verziehen (max. 3 im
  Reservoir gleichzeitig). `players.streak_savers` Drift-Spalte;
  `StreakService.currentStreak` konsumiert Saver automatisch und
  persistiert. Tests decken Single-Lücke, Doppel-Lücke und Cap ab.
- **Doppel-Punkte-Boost**: nächstes Quiz nach Erreichen von Tag 7
  zählt ×2. `players.double_points_remaining` Drift-Spalte. Banner
  im `QuizSetupScreen` zeigt aktiven Boost an.
- **Sonder-Dialog** für Tag 7: alle drei Geschenke werden aufgezählt;
  andere Stufen behalten den normalen Bonus-Dialog.

### Added — Roadmap (späteres Release)
- **Avatar-System**: Initialen-Avatar mit Markenpalette als Phase A,
  freischaltbare Avatar-Sets (Globus, Buch, Sprechblase…) bei
  Streak-/Score-Meilensteinen als Phase B. Persistenz via neuer
  Player-Spalte + Firestore-Sync. Siehe PROJECT.md § 12.

### Fixed — Iteration 20 (Karo-Muster im Splash + hellerer Icon-BG)
- **Karo-Muster im Splash entfernt**: Die Quell-PNGs (`bunt.png`/`sw.png`)
  hatten das Transparenz-Karo direkt in die RGB-Daten geflattet (Alpha=255
  überall). Auf Android-12-Splash schien das Karo durch. Fix per
  zweistufiger `ffmpeg geq`-Pipeline:
  1. Grauwerte (R≈G≈B) im mittleren Helligkeitsbereich → Alpha=0 (Karo
     außerhalb des grünen Kreises wird transparent).
  2. „grünlich-grau" innerhalb des Kreises → ersetzt mit solidem
     Forst-Grün `#314e32` (sonst zeigt der semi-transparente Design-
     Kreis weiter sein Karo).
- **`logo_splash.png`** neu generiert mit Sage-Hintergrund (`#7CB58F`)
  fest eingebrannt — keine Transparenz mehr im Splash-Asset.
- **Adaptive-Icon-Hintergrund heller**: `#7CB58F` → **`#C5E0CD`** (heller
  Mint-Ton) — der dunkelgrüne Motiv-Kreis pop deutlicher auf dem
  Launcher-Bildschirm.
- Splash-Hintergrund bleibt `#7CB58F` (unverändert — User mag die Farbe).

### Changed — Iteration 19 (Splash länger sichtbar, hellerer Hintergrund)
- **Splash-Mindestdauer 1.5 s**: `FlutterNativeSplash.preserve` in `main.dart`
  hält die Anzeige aktiv, bis der Firebase-Init durch ist *und* mindestens
  1500 ms vergangen sind — vorher war der Splash nur kurz sichtbar, weil
  Flutter ihn beim ersten Frame entfernt.
- **Hintergrundfarbe heller**: `#2E5C42` (Dunkelgrün) → **`#7CB58F`**
  (helles Salbei-Grün) — sowohl für den Adaptive-Icon-Background als
  auch den Splash. Lässt den dunkelgrünen Kreis im Vordergrund besser
  pop.
- `flutter_native_splash` umgezogen von `dev_dependencies` nach
  `dependencies`, weil `preserve/remove` zur Laufzeit gebraucht wird.

### Added — Iteration 18 (App-Icon + Splash + Launcher-Name)
- **Eigenes App-Icon** ersetzt den Flutter-Default. Master-Assets liegen
  unter `assets/branding/logo_foreground.png` (bunte Vorder-Variante mit
  Globus, Buch und Sprechblase) und `logo_monochrome.png` (Silhouette für
  Android-13-Themed-Icons).
- **Adaptive Icon** mit dunkelgrünem Hintergrund `#2E5C42`, generiert via
  `flutter_launcher_icons` — alle Density-Buckets, Round-Icon und
  Monochrome-Variante automatisch ableitbar.
- **Splash-Screen** mit Logo zentriert auf demselben Grün, generiert via
  `flutter_native_splash` (inkl. Android-12-SplashScreen-API und
  Dark-Mode-Variante).
- **`android:label`** in `AndroidManifest.xml` von `vocabularies_kroatic`
  auf **`Vokabeltrainer`** geändert — der Launcher zeigt jetzt den
  schönen Namen unter dem Icon.

### Changed — Iteration 17.1 (Versions-Schema)
- App-Version umgestellt von `1.0.0+14` auf **`1.0.17`** (MAJOR.MINOR.ITERATION).
  Anzeige im Drawer-Footer und im Über-Dialog folgt automatisch.
- Konvention dokumentiert in `lib/shared/app_info.dart`: pro Iteration
  PATCH +1, MINOR steigt nur bei größeren Feature-Paketen, MAJOR bei
  Generations-Sprüngen. `kAppBuild` entfällt; `pubspec.yaml` hält den
  `+N`-Build-Code (Android `versionCode`) jetzt synchron mit dem Patch.

### Changed — Iteration 17 (Bild-Joker → Vorlesen-Joker)
- **🔊 Vorlesen** ersetzt **🖼️ Bild**. Der dritte Joker spielt jetzt die
  richtige Antwort per TTS in der Zielsprache vor (8 P statt 10 P).
  Universell verfügbar — kein Icon-Mapping nötig, fällt nie weg.
  Die Reveal-Karte zeigt einen „Nochmal"-Button für erneutes Abspielen.
- **`QuizQuestion.pictureIcon`** und die Datei `vocab_icons.dart` entfernt;
  `QuizBuilder` reicht das Feld nicht mehr durch.
- Bestehende `picture`-Codes in `jokers_json` älterer Sessions werden in
  `session_detail_service` still gefiltert (`whereType<JokerType>()`).

### Added — Iteration 16 (Quiz-Reihenfolge + Streak-Diagnose)
- **Quiz startet mit Wörtern**: Nach der Frage-Auswahl im `QuizBuilder`
  werden die 10 Fragen stabil nach Stage sortiert — erst `words`, dann
  `phrases`, dann `sentences`. Damit beginnt jedes Quiz mit den leichten
  Vokabeln; die spaced-repetition-Reihung des `QuizSelector` bleibt
  innerhalb derselben Stage erhalten. Greift auch im „Fehler ausbessern"-
  Modus.
- **Streak-Diagnose im Profil**: aufklappbare Karte zeigt Spieler-ID,
  Heutiges Datum, aktueller Streak, finalisierte/unfertige Sessions sowie
  die letzten 14 distinkten Spieltage. Hilft beim Debuggen, wenn der
  Streak-Banner nicht hochzählt.
- **Neue DB-Query** `unfinishedSessionsCountForPlayer(playerId)`: zählt
  Sessions ohne `finishedAt` — sichtbar im Diagnose-Block.

### Changed — Iteration 16
- `_computeCurrentStreak` rechnet den Vortag jetzt per Kalender-Arithmetik
  (`DateTime(y, m, d - 1)`) statt `subtract(Duration(days: 1))` — robust
  gegen DST-Sprünge.

### Added — Iteration 15 („Fehler ausbessern"-Menüpunkt)
- **Dritte Karte im `LessonMenuScreen`**: „Fehler ausbessern" — startet ein
  Quiz mit ausschließlich den Items, bei denen der Spieler in dieser
  Lektion zuletzt falsch geantwortet hat. Anzeige der Item-Anzahl im
  Subtitle; Karte ausgegraut, wenn der Pool leer ist.
- **DB-Query** `wrongItemsForLesson(playerId, lessonId)`: nimmt pro Item
  den letzten Versuch (über alle Richtungen) und filtert auf
  `wasCorrect == false`.
- **QuizSessionArgs.reviewMode**: neues Flag. Der `QuizBuilder` akzeptiert
  einen optionalen `itemPoolOverride`; Distractoren ziehen weiter aus der
  ganzen Lektion, damit MC seine 4 Optionen behält.
- **QuizSetupScreen** im Review-Modus: Titel „Fehler ausbessern", Button
  zeigt „Fehler wiederholen (N)" statt „Quiz starten (10)".
- **Provider** `wrongItemsCountProvider(lessonId)`: wird nach jedem
  Session-Finalize invalidiert, damit die Karte sofort die aktuelle Zahl
  zeigt.

### Added — Iteration 14 (Cloud-Login + globale Highscores + Streaks)
- **About-Dialog**: Version + Tagline + Beschreibung wandern aus dem
  schmalen Header in den Dialog-Body — keine abgeschnittenen Texte mehr.
- **Firebase-Integration** (firebase_core/auth/cloud_firestore) mit
  Graceful Degradation: ohne `flutterfire configure` läuft die App
  weiter im reinen Lokal-Modus, Login + Global-Leaderboard werden
  ausgeblendet.
- **E-Mail+Passwort-Login**: neuer Drawer-Eintrag „Anmelden /
  Registrieren" → `LoginScreen` mit Tabs Anmelden/Registrieren +
  Passwort-Reset. Eingeloggte sehen „Mein Profil" → `ProfileScreen`
  mit Streak-Counter und Abmelden-Button.
- **Globale Bestenliste**: Highscore-Screen bekommt SegmentedButton
  „Lokal / Global". Globale Einträge kommen aus Firestore-Collection
  `scores`, sortiert nach `scorePoints DESC, durationMs ASC`.
  `firestore.rules` im Repo-Root: jeder darf lesen, eingeloggte nur
  eigene Scores schreiben, Edits/Deletes nicht erlaubt.
- **Upload-Hook**: Nach Quiz-Finalize wird die Session automatisch
  fire-and-forget zu Firestore hochgeladen, sofern eingeloggt.
  Offline = nur lokal, keine Fehlermeldung.
- **Streak-System**: zählt aufeinanderfolgende Kalendertage mit
  abgeschlossenen Sessions. 🔥-Pille im Home-AppBar, Anzeige im
  Profil. Meilensteine 3/7/14/30/60/100 Tage geben +50/+150/+400/
  +1000/+2500/+5000 Bonuspunkte für den jeweils nächsten Quiz.
  Bonus wird aus `Players.pendingBonusPoints` beim Session-Finalize
  konsumiert. Neue Drift-Tabelle `StreakRewards` + Schema-Migration
  auf v5. Reward-Dialog erscheint nach erreichtem Meilenstein-Tag.
- **Setup-Hinweis**: Vor Erstinbetriebnahme muss einmal
  `flutterfire configure` ausgeführt werden, um Firebase-Optionen
  zu erzeugen (siehe README/PROJECT.md). Bis dahin laufen alle
  bisherigen Features unverändert.

### Tests
- Neue `streak_service_test.dart` mit 12 Cases (Streak-Berechnung,
  Tagestoleranz, Lücken, Mehrfach-Sessions, Reward-Stufen).
- Gesamte Test-Suite: 34 Tests, alle grün.

### Changed — Iteration 12 (STT läuft online, kein Install-Pfad mehr)
- **STT-Pre-Check entfernt**: bisher prüfte die App via
  `speech_to_text.locales()`, ob das Ziel-Locale (hr-HR) bekannt
  ist, und deaktivierte das Mikro andernfalls. Die Liste reflektiert
  jedoch nur **installierte Offline-Pakete**. Kroatisch ist auf den
  meisten Geräten gar nicht als Offline-Paket downloadbar — die
  Prüfung lieferte daher false-negatives und blockierte das Mikro
  grundlos, obwohl Online-STT für hr problemlos läuft.
- **Mikro immer klickbar**: keine `_localeAvailable`-State-Maschine
  mehr in `QuizMicInput`, kein „Sprache installieren"-CTA. Der
  Nutzer probiert direkt; bei Recognizer-Fehler erscheint
  ein Inline-Hinweis „Spracherkennung läuft online — bitte
  Internetverbindung prüfen."
- **`SpeechListenOptions(onDevice: false)`** explizit gesetzt in
  `SttService.start`, damit die Online-Intention im Code sichtbar
  ist (war vorher das Default-Verhalten der deprecated Parameter).
  `cancelOnError: true` sorgt dafür, dass eine fehlgeschlagene
  Session sauber endet.
- **`SttService.hasLocale`/`_langPrefix` gelöscht** (kein Aufrufer
  mehr); `_activeOnError`-Bridge reicht Plugin-Fehler aus
  `initialize.onError` an den aktiven `start`-Call durch.
- **Aufräumen**: `MissingLanguageDialog` ist jetzt TTS-only
  (`showMissingTtsLanguageDialog`). STT-Branch, `LanguageFeature`-
  Enum, `SystemIntents.openSttRecognitionSettings`,
  `openVoiceInputSettings` und `openInputMethodSettings` entfernt.
  Das AndroidManifest-`<queries>`-Element listet nur noch die
  TTS-relevanten Packages (`com.google.android.tts`,
  `com.google.android.googlequicksearchbox`).
- **TTS-Pfad unverändert** — dort ist Install-UX weiter sinnvoll,
  weil Kroatisch als TTS-Stimme tatsächlich per Google TTS
  installierbar ist.

### Changed — Iteration 11 (bessere Deep-Links für „Sprache installieren")
- **STT-Dialog**: `VOICE_INPUT_SETTINGS` führte auf „Digitale
  Assistenz-App" (falsche Seite). Ersetzt durch
  `INPUT_METHOD_SETTINGS` (Tastaturen-Liste) und einen
  zweiten Knopf „Google-App öffnen", der die Google-App startet
  (`AndroidIntent(action: MAIN, package: …)`, Fallback auf
  Play-Store). Dialog erklärt schrittweise den Weg:
  Tastatureinstellungen → Gboard → Spracheingabe →
  Offline-Spracherkennung → Sprachen → Hrvatski.
- **TTS-Dialog**: zusätzlicher Button „App-Info: Google TTS"
  öffnet `APPLICATION_DETAILS_SETTINGS` für
  `com.google.android.tts` (Update-Suche möglich). Dialog
  führt jetzt Schritt-für-Schritt: Sprachdienste →
  Bevorzugte Engine → Zahnrad → Sprachen → Hrvatski.
- Dialog-Body wurde generell zu einer nummerierten Anleitung
  ausgebaut, mit primärem `FilledButton` und sekundärem
  `OutlinedButton` direkt im Content; „Schließen" und
  „Im Play Store" bleiben in den `AlertDialog.actions`.

### Added — Iteration 10 (Joker-System)
- **Drei Joker-Typen** ersetzen den bisherigen generischen Hinweis:
  - **Lautschrift (🔤)** — zeigt das IPA der Antwort, Strafe −5 P.
    Disabled wenn das Item kein IPA hat.
  - **50/50 (✂)** — dimmt zwei falsche Optionen visuell + macht sie
    untappbar, Strafe −15 P. Nur im Auswählen-Modus aktiv. Auswahl
    deterministisch aus `sessionId ⊕ questionOrder`.
  - **Bild (🖼)** — blendet ein zur Vokabel passendes Material-Icon
    ein, Strafe −5 P. ~60 Mappings in `VocabIcons` (Farben, Tiere,
    Verkehr, Möbel, Essen).
- **JokerBar** ersetzt das alte `quiz_hint_panel.dart`: drei kompakte
  Joker-Buttons nebeneinander, jeder mit Icon, Label, Strafe und
  Tooltip. Reveal-Cards für IPA/Bild klappen darunter aus; mehrere
  Joker auf derselben Frage erlaubt.
- `computeScore` neu mit `jokerCost`-Parameter; ScoreExplanationDialog
  zeigt die drei Strafen aufgelistet + Beispielrechnung.
- **DB-Schema v4**: `quiz_attempts.jokersJson` (Text, nullable, JSON-
  Liste der Joker-Codes pro Versuch). Migration v3→v4 ist additiv.
- Session-Detail-Screen zeigt pro Versuch die Joker-Icons; alte
  Versuche mit `hintUsed=true` ohne `jokersJson` zeigen das generische
  💡 (Backward-Compat).
- Unit-Tests `test/joker_score_test.dart`: 4 Cases für `computeScore`
  + 5 Cases für `jokerAvailable`. Gesamt 22 Tests grün.

### Added — Iteration 9 („Sprache installieren"-Deep-Link)
- Tap auf einen disabled-Lautsprecher-Button öffnet jetzt einen
  `MissingLanguageDialog` mit Erklärung + Buttons „Sprachdienste
  öffnen" (Android-Intent `com.android.settings.TTS_SETTINGS`) und
  „Im Play Store" (`market://details?id=com.google.android.tts`).
- Im Quiz-Modus „Sprechen" / „Hören + Sprechen" zeigt das Mikrofon-
  Widget bei fehlendem STT-Sprachpaket einen `FilledButton.tonalIcon`
  „Sprache installieren". Tap öffnet den Dialog mit
  `android.settings.VOICE_INPUT_SETTINGS` und Play-Store-Listing der
  Google-App als Optionen.
- Neue Service-Klasse `SystemIntents` bündelt Android-Intents zentral.
  Auf nicht-Android-Plattformen sind die Helper No-ops.
- `TtsService.invalidate([langTag])` und `SttService.invalidate()`
  verwerfen die Verfügbarkeits-Caches, damit nach manueller
  Installation der Sprache der Knopf beim nächsten Tap wieder aktiv
  wird, ohne App-Neustart.
- Neue Abhängigkeit: `android_intent_plus: ^5.3.0`.

### Added — Iteration 8 (vier Quiz-Formate)
- **`QuizFormat`-Enum** mit vier Formaten, pro Session in der
  Lesson-Detail-Card als `ChoiceChip` wählbar (☐ Auswählen,
  ✎ Schreiben, 🎤 Sprechen, 👂 Hören & Sprechen).
- **Schreiben** (`type`): Textfeld + Submit-Button. Auswertung über
  `AnswerEvaluator`: strict-equal → ok; tolerant-equal (Großklein,
  Apostrophe, Endpunkte, Whitespace egalisiert, **Diakritika strict**)
  → ok mit Schreibweise-Hinweis „Achte auf die Schreibweise: …".
- **Sprechen** (`speak`): Prompt-Text sichtbar; Mikrofon-Tap startet
  STT (`speech_to_text`), Live-Transkript wird angezeigt, am Ende der
  Erkennung als Antwort gewertet (gleicher Evaluator wie type).
- **Hören & Sprechen** (`listenSpeak`): Prompt-Text **versteckt**, der
  TTS-Engine spielt das Wort automatisch ab; tap auf die Hör-Karte
  spielt erneut. Antwort via Mikrofon, Auswertung gleicher Evaluator.
  Erst nach der Antwort wird der Prompt-Text eingeblendet.
- **Feedback-Karte** unter der Antwort-Area: ✓ „Richtig!" / ✗
  „Falsch." mit korrekter Lösung, Speaker-Button daneben (HR), bei
  Schreibweise-Hinweis kursive Zeile darunter.
- DB-Schema **v3**: `quiz_sessions.direction` (`de_hr` / `hr_de`)
  ergänzt, Migration backfilled aus dem alten Mode-Suffix. Adaptive
  Selektion und Highscore-Filter laufen jetzt richtungsbasiert, nicht
  mehr modusabhängig — modusübergreifender Lernfortschritt.
- AndroidManifest: `RECORD_AUDIO`-Permission + `<queries>`-Eintrag für
  `android.speech.RecognitionService`.
- Unit-Tests `test/answer_evaluator_test.dart` (8 Fälle) decken
  strict/tolerant/wrong, Case-Insensitivity, Apostroph-Toleranz,
  Whitespace-Normalisierung, Endpunkt-Toleranz und Diakritika-Strenge ab.

### Added — Iteration 7 (Sprachausgabe / TTS)
- **`TtsService`** als dünner Wrapper um `flutter_tts`, mit lazy
  Engine-Init (Speech-Rate 0.45, Volume 1.0), kachiertem
  `isLanguageAvailable`-Check je Sprache (hr-HR, de-DE) und
  Sprachwechsel nur bei Bedarf.
- **`SpeakButton`** als wiederverwendbares Icon: zeigt
  `volume_up_outlined`, beim Drücken `graphic_eq` (während des Sprechens),
  `volume_off_outlined` wenn die System-TTS die angefragte Sprache
  nicht installiert hat (Button dann deaktiviert mit Tooltip).
- Audio-Buttons eingebaut in:
  - **Lesson-Detail-Item-Karte**: DE-Text (de-DE) und HR-Text (hr-HR)
    jeweils einzeln aussprechbar.
  - **Quiz-Prompt-Karte**: spricht das aktuell gefragte Wort in der
    Prompt-Sprache (hängt von Quiz-Richtung ab).
  - **Highscore-Session-Detail / AttemptRow**: spricht die kroatische
    Vokabel jedes Versuchs (hr-HR) zur Nachbereitung.

### Added — Iteration 6 (Adaptive Quiz-Auswahl + Highscore-Detail)
- **Adaptive Quiz-Selektion**: Statt immer der gleichen 10 leichtesten
  Items teilt der neue `QuizSelector` die Vokabel-Pool in drei Buckets
  (NEW / STUMBLED / MASTERED) und zieht 6 + 3 + 1, mit Auffüll-Fallback.
  Innerhalb jedes Buckets werden „am längsten nicht gesehene" Items
  bevorzugt. Falsch beantwortete Vokabeln tauchen verlässlich wieder
  auf, gemeisterte werden gelegentlich zur Sicherung erinnert.
  DAO `attemptStatsByItem(playerId, mode)` aggregiert Treffer-Historie
  in einem Drift-JOIN.
- **HighscoreScreen-Filter**: Über den vier Zeitfenstern liegt eine
  horizontal scrollbare FilterChip-Reihe mit „Alle" + den 9 Lektionen.
  Auswahl wirkt sich auf alle Tabs aus.
- **Session-Detailansicht**: Tap auf eine Bestenlisten-Zeile öffnet
  `SessionDetailScreen` mit Header-Statistik (Treffer, Quote, Zeit,
  Hinweise, Punkte, Richtung) und den 10 Versuchen in
  Frage-Reihenfolge — pro Versuch ✓/✗, Vokabel-Paar, gewählte Option
  (bei Falschen), Antwortzeit, Hinweis-Marker.
- Unit-Tests `test/quiz_selector_test.dart` decken Erstspiel-, Stumbled-
  und Steady-State-Verhalten der Bucket-Logik ab.

### Fixed — Iteration 5 Hotfix
- **Sync fiel auf Offline-Cache zurück**: das in `advanced.json`
  ausgelieferte `stages`-Array entsprach nicht dem Freezed-Schema
  (`type` fehlte, `order` fremd). Das Freezed-Parsing flog deshalb,
  die ganze Sync wurde gecatcht und als „fromCache" markiert.
  Datenrepo-Hotfix `50f381a` korrigiert das Stages-Format, App-seitig
  keine Änderung nötig.

### Added — Iteration 5 (Datenrepo-Erweiterung + Quiz-Politur)
- **Neue Lektion „Fortgeschritten"** wird beim App-Start automatisch
  vom Manifest gezogen — 286 zusätzliche Items aus der eigenen
  Vokabel-Sammlung, gegen die bestehenden 8 Lektionen entdupliziert
  (`vocabularies-kroatic-data` 1.2.0).
- Icon `psychology_outlined` für die neue Topic-Karte.

### Changed — Iteration 5
- **Quiz-Prompt-Karte ohne `DE`/`HR`-Label**: über dem abgefragten
  Vokabeltext steht jetzt nur noch der Text selbst — die Sprache ist
  durch die Richtungsanzeige in der AppBar (`🇩🇪→🇭🇷` / `🇭🇷→🇩🇪`) und
  die Richtungswahl im Lesson-Detail bereits klar.
- **Pull-to-Refresh** auf dem Home-Screen: nach unten ziehen +
  loslassen löst eine Re-Sync aus (`syncResultProvider` wird
  invalidiert, `cachedLessonsProvider` neu aufgelöst). Ersetzt die
  Funktion des in Iteration 4 entfernten Refresh-Icons in der AppBar.

### Added — Iteration 4 (Bestenliste-UI + Navigation)
- **HighscoreScreen** mit 4 Tabs (Heute / Woche / Monat / Ewig). Pro
  Eintrag: Rang (🥇🥈🥉 für Top 3, danach Zahl), Spielername, Score,
  Treffer/Total, Lektion, Richtung, Dauer, relatives Datum.
- **Drawer-Menü** links neben „Vokabeltrainer" mit Header (`🇩🇪 ↔ 🇭🇷`)
  und den Einträgen „Lektionen" (aktiv markiert) und „Bestenliste".
- **Info-Dialog** zur Punkte-Formel in der Highscore-AppBar:
  `Treffer × 100 + max(0, 600 − Sekunden) − Hinweise × 5`, inkl.
  konkretem Beispiel.
- DAO `AppDatabase.topSessionsDetailed(...)` joint Sessions mit
  `players` und `lessons_cache`, sodass Anzeigename und Lektions-Titel
  ohne N+1-Queries verfügbar sind.
- `LeaderboardRange`-Enum mit `boundsNow()` für die vier Zeitfenster
  (lokale Mitternachts-Grenzen, Wochenstart Montag).

### Changed — Iteration 4
- **QuizOptionButton** zeigt keinen Sprach-Chip mehr vor dem Vokabeltext
  — die Sprache der Optionen ist bereits durch die Prompt-Karte oben
  eindeutig.
- **Refresh-Button** aus der Home-AppBar entfernt (Sync läuft beim
  App-Start automatisch, Re-Sync kommt bei Bedarf später in den Drawer).

### Added — Iteration 3 (Lernspiel + Highscore-Fundament)
- **Multiple-Choice-Quiz** je Lektion: 10 Vokabeln, leichteste zuerst
  (`difficulty ASC`), 4 Optionen aus derselben Lektion, falsche Auswahl
  markiert beide Karten farblich. Erreichbar über „Quiz starten (10)" im
  `LessonDetailScreen`.
- **Bidirektionale Lernrichtung**: Pro Quiz-Session zwischen `🇩🇪 → 🇭🇷` und
  `🇭🇷 → 🇩🇪` umschaltbar. AppBar-Titel im Home-Screen zeigt `🇩🇪 ↔ 🇭🇷` als
  Hinweis auf die unterstützten Richtungen.
- **„Neu eingeführt"-Hinweis**: Bei einem Wort, das in der gewählten
  Richtung noch nie abgefragt wurde, wird der Hinweis-Button mit einer
  `NEU`-Marke versehen; Aufdecken zeigt IPA, Notiz oder Anfangsbuchstaben.
- **Zusammenfassungs-Screen**: Richtige / gesamt, Trefferquote in Prozent,
  Zeit `mm:ss`, Hinweis-Anzahl und Punkte (`correct*100 + max(0, 600-sek) - hints*5`).
- **Multi-User-Datenmodell vorbereitet** (Drift-Schema v2):
  - `players` (UUID, lokaler Default „Du", `remoteUserId` für späteres Cloud-Sync),
  - `quiz_sessions` (Modus, Start/Ende, Zähler, Score) und
  - `quiz_attempts` (pro Frage: Treffer, Hinweis-Nutzung, Antwortzeit).
  - DAO `topSessions(sinceMs, untilMs, lessonId?)` als Basis für die
    Daily/Weekly/Monthly/Ewig-Bestenlisten, die in einer kommenden Iteration
    eine UI bekommen.

### Changed
- Daten-Repo `vocabularies-kroatic-data` auf Version **1.1.0** angehoben:
  alle 8 Lektionen auf ~100 Items hochgezogen, insgesamt **805 Items**
  (538 Wörter, 144 Phrasen, 123 Sätze) statt 339. Schwierigkeitsspanne
  pro Lektion umfasst nun 4–5 Stufen (1–5). Details siehe
  [Daten-Repo CHANGELOG.md](../vocabularies-kroatic-data/CHANGELOG.md).
- App-seitig kein Code-Change nötig — Versionierung pro Lektion sorgt
  dafür, dass der Manifest-Loader die geänderten Lektionen automatisch
  nachzieht und in die lokale Drift-DB upsertet. Bestehender
  Lernfortschritt bleibt erhalten (ID-Stabilität).

### Added
- Initiale Projektdokumentation `PROJECT.md` mit 13 Sektionen:
  Projektüberblick, Lernkonzept & Didaktik, Inhaltsquellen & Lizenzen,
  externes JSON-Datenschema, Tech-Stack & Architektur, lokales Datenmodell,
  Spaced-Repetition-Algorithmus (SM-2), Sprach-Features (STT/TTS/Aussprache-Score),
  App-Flows & Screens, Projektstruktur, APK-Build-Anleitung, Roadmap (4 Phasen),
  Glossar & Referenzen.
- Definition der Schwierigkeitsstufen 1–5 (Basis → Fortgeschritten) und
  der Typ-Trennung `word` / `phrase` / `sentence` mit zugehörigen Stages.
- Verlinkung auf das separate Daten-Repository
  `vocabularies-kroatic-data` mit initialem Manifest und 8 Lektions-JSONs.
- `README.md` als Kurzeinstieg mit Verweis auf `PROJECT.md`.

### Planned — Phase 1 (MVP)
- Flutter-Projekt-Skelett (`pubspec.yaml`, `lib/main.dart`)
- Drift-Datenbank-Schema (Tabellen `items`, `progress`, `lessons_cache`)
- Manifest-basierter JSON-Loader mit ETag-Cache
- SM-2-Scheduler (Text-only, ohne Speech)
- Erste 3 Lektionen produktiv: greetings, introduction, numbers-time
- APK-Build-Pipeline (Debug + unsigned Release)

### Planned — Phase 2 (v0.2)
- TTS-Integration (`flutter_tts`, hr-HR)
- STT-Integration (`speech_to_text`, hr-HR)
- Pronunciation Score (Levenshtein-basiert, Diakritika-aware)
- Error-Focus-Modus (Top-30 schwierigste Items)
- 5 weitere Lektionen aus dem Daten-Repo befüllen

---

## Versionierungs-Hinweise

- **App-Versionen** folgen Semantic Versioning (`MAJOR.MINOR.PATCH`).
- **Daten-Versionen** werden im separaten Repo
  [`vocabularies-kroatic-data`](https://github.com/mfred/vocabularies-kroatic-data)
  gepflegt — siehe dortige `CHANGELOG.md` für Inhaltsänderungen.
- Schema-Änderungen am Datenformat werden hier als App-Patch dokumentiert,
  Inhalts-Änderungen dort.
