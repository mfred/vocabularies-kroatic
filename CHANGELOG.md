# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

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
