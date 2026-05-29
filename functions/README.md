# Cloud Functions — vocabularies-kroatic

Server-seitige Ergänzungen aus dem Code-Audit (Tranche 4). **Noch nicht
deployt** — dieses Verzeichnis ist das Gerüst; der Deploy erfolgt manuell.

## Funktionen

| Funktion | Trigger | Zweck | Befund |
|---|---|---|---|
| `aggregateScore` | `onCreate scores/{id}` | pflegt `leaderboard_totals/{uid}` (Summe + Spielzahl) fort | M9 (Leaderboard lädt sonst bis zu 2000 Docs) |
| `finalizeDuel` | `onUpdate duels/{id}` | leitet `winnerUid` server-autoritativ aus den gemeldeten Zeiten ab | H3 (Gewinner war client-bestimmt) |

Beide sind **nicht-brechend**, wenn isoliert deployt: `aggregateScore` befüllt
nur eine neue, vom Client noch ungelesene Collection; `finalizeDuel` schreibt
denselben `winnerUid`, den der Client schon berechnet.

## Voraussetzungen

- Firebase **Blaze**-Plan (Functions brauchen aktivierte Abrechnung).
- `firebase-tools` CLI (`npm i -g firebase-tools`), eingeloggt (`firebase login`).
- Node 20.

## Deploy

```bash
cd functions && npm install
firebase deploy --only functions
```

Danach die zugehörige Regel für die Aggregat-Collection mitdeployen
(`firestore.rules` enthält bereits `leaderboard_totals`: read public, write nur
über Admin-SDK):

```bash
firebase deploy --only firestore:rules
```

## Lokal testen (Emulator, kein Prod-Risiko)

```bash
cd functions && npm install
firebase emulators:start --only functions,firestore
```

## Offene Folgeschritte (bewusst noch NICHT umgesetzt)

1. **Client auf `leaderboard_totals` umstellen**: `RemoteLeaderboardService.top()`
   für die „Ewig"-Liste auf `leaderboard_totals` (orderBy `totalScorePoints`,
   `.limit(50)`) umbauen statt 2000 Score-Docs zu scannen. Für die Zeitfenster
   (heute/Woche/Monat) zusätzliche Bucket-Docs in `aggregateScore` fortschreiben.
2. **Client hört auf, `winnerUid` zu setzen** (`DuelService.submitOpponentResult`)
   und die `duels`-update-Rule verbietet client-gesetztes `winnerUid` — dann ist
   der Sieger vollständig server-autoritativ.
3. **Server-autoritatives Scoring** (volle Cheat-Sicherheit der Bestenliste):
   architektonisch groß, weil der Score aktuell von **lokal-first** State abhängt
   (`pendingBonusPoints`, Streak-Saver, Doppel-Punkte liegen nur in der lokalen
   Drift-DB). Saubere Lösung: Quiz-Abschluss als Callable Function, die die
   Roh-Antwortdaten + den (dann nach Firestore migrierten) Bonus-Zustand
   server-seitig neu berechnet. Bewusst als größeres eigenes Vorhaben offen.
