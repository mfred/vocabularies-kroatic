# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

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
