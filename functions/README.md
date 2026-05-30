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

### Einmaliges Backfill (Pflichtschritt beim ersten Deploy)

`aggregateScore` triggert nur `onCreate` — nach dem Deploy enthält
`leaderboard_totals` daher nur **neue** Scores. Damit die „Ewig"-Bestenliste
nicht auf Post-Deploy-Punkte schrumpft, die bestehende `scores`-Historie einmalig
nachfüllen. Das Skript schreibt **absolute** Summen via `.set({merge:true})` (kein
`increment`) und ist damit gefahrlos wiederholbar:

```bash
cd functions && npm install
# Auth: GOOGLE_APPLICATION_CREDENTIALS=pfad/zu/serviceAccount.json
#   (oder `firebase login` + Application Default Credentials)
node scripts/backfill_leaderboard_totals.js
```

Reihenfolge: erst `firebase deploy --only functions`, dann das Backfill zuletzt.
Ein erneuter Lauf ist sicher (überschreibt mit denselben Werten).

## Lokal testen (Emulator, kein Prod-Risiko)

```bash
cd functions && npm install
firebase emulators:start --only functions,firestore
```

Damit lässt sich der Iter-66-Client-Pfad ohne Prod-Risiko prüfen:

1. Ein paar `scores`-Docs seeden → `aggregateScore` füllt `leaderboard_totals`;
   die App (gegen den Emulator) zeigt im Ewig-Tab dieselben Ränge wie der Scan.
2. Backfill gegen vorab geseedete Historie laufen lassen
   (`FIRESTORE_EMULATOR_HOST=localhost:8080 node scripts/backfill_leaderboard_totals.js`)
   → absolute Summen; ein zweiter Lauf lässt die Werte unverändert (Idempotenz).
3. Negativpfad: `leaderboard_totals` leer lassen → der Ewig-Tab rendert weiter
   über den Scan-Fallback.

## Offene Folgeschritte (bewusst noch NICHT umgesetzt)

1. **Client auf `leaderboard_totals` umstellen** — Client-Code liegt vor (Iter 66),
   ist aber **per Flag deaktiviert und ins Backlog verschoben (Iter 67)**, weil der
   Functions-Deploy den Blaze-Plan (kostenpflichtig) braucht, der vorerst nicht
   aktiviert wird. `RemoteLeaderboardService.top()` liest die „Ewig"-Liste aus
   `leaderboard_totals` (orderBy `totalScorePoints`, `.limit(50)`, Fallback auf den
   2000-Doc-Scan) **nur, wenn `_useAggregateLeaderboard == true`** — aktuell `false`,
   die App arbeitet also wie vor Iter 66.
   **Reaktivierung:** Flag auf `true`, dann `firebase deploy --only
   functions,firestore:rules` und einmalig das Backfill (s. o.). **Danach noch offen:**
   die **Zeitfenster** (heute/Woche/Monat) brauchen zusätzliche Bucket-Docs in
   `aggregateScore` (z. B. `leaderboard_daily/{yyyymmdd}/{uid}`) — bis dahin scannen
   diese drei Tabs weiterhin `scores`.
2. **Client hört auf, `winnerUid` zu setzen** (`DuelService.submitOpponentResult`)
   und die `duels`-update-Rule verbietet client-gesetztes `winnerUid` — dann ist
   der Sieger vollständig server-autoritativ.
3. **Server-autoritatives Scoring** (volle Cheat-Sicherheit der Bestenliste):
   architektonisch groß, weil der Score aktuell von **lokal-first** State abhängt
   (`pendingBonusPoints`, Streak-Saver, Doppel-Punkte liegen nur in der lokalen
   Drift-DB). Saubere Lösung: Quiz-Abschluss als Callable Function, die die
   Roh-Antwortdaten + den (dann nach Firestore migrierten) Bonus-Zustand
   server-seitig neu berechnet. Bewusst als größeres eigenes Vorhaben offen.
