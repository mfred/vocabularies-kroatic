# vocabularies-kroatic

Vokabeltrainer Deutsch ↔ Kroatisch — Android-App (Flutter) mit
Spaced Repetition, Spracheingabe und Aussprachebewertung.

## Schnellstart-Doku

Die vollständige Konzept-, Architektur- und Build-Dokumentation steht in
[**PROJECT.md**](./PROJECT.md). Dort finden sich u.a.:

- Lernkonzept & didaktische Progression (Wort → Phrase → Satz, Schwierigkeit 1–5)
- Inhaltsquellen (Tatoeba CC-BY 2.0, eigene Kuration CC-BY 4.0, Anki-Inspiration)
- JSON-Schema des externen Daten-Repos
- Tech-Stack (Flutter, Riverpod, Drift, speech_to_text, flutter_tts)
- SM-2 Spaced-Repetition-Algorithmus
- APK-Build-Anleitung
- Roadmap (4 Phasen: MVP → v1.0)

Änderungshistorie: [CHANGELOG.md](./CHANGELOG.md).

## Status

Produktiv — App **v1.0.69**, lauffähige Release-APK, 12 Lektionen mit ~1.622
Items. Aktive Iterations-Entwicklung (siehe [PROJECT.md](./PROJECT.md) §12 und
[CHANGELOG.md](./CHANGELOG.md)). Stand: 2026-05-30.

## Daten-Repository

Vokabeln liegen in einem separaten Repo, damit Inhaltsupdates kein
App-Update erfordern:

```
https://github.com/mfred/vocabularies-kroatic-data
```

Lokal: `../vocabularies-kroatic-data/`

## Lizenz

App-Code: später, vorerst all rights reserved.
Datenrepo: CC-BY 4.0 für eigenkurierte Inhalte; Tatoeba-Inhalte CC-BY 2.0
attribuiert.
