'use strict';

// Cloud Functions für vocabularies-kroatic.
//
// Deploy:  firebase deploy --only functions
// Voraussetzung: Firebase Blaze-Plan (Functions brauchen Abrechnung aktiviert).
//
// Beide Funktionen sind NICHT-BRECHEND, wenn sie isoliert deployt werden:
//  - aggregateScore befüllt nur eine neue Collection (leaderboard_totals), die
//    der Client (noch) nicht liest.
//  - finalizeDuel überschreibt winnerUid mit demselben Wert, den der Client
//    bereits berechnet — bis der Client aufhört, winnerUid selbst zu setzen
//    (geplanter Folgeschritt + Rules-Verschärfung), ist es effektiv ein No-op.

const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

// ---------------------------------------------------------------------------
// M9: Leaderboard-Aggregation. Statt bis zu 2000 Score-Docs pro Bestenlisten-
// Abruf clientseitig zu summieren, pflegt diese Funktion server-seitig ein
// Aggregat pro Spieler fort. Der Client kann später `leaderboard_totals` direkt
// nach `totalScorePoints` sortiert mit `.limit(50)` lesen (O(50) statt O(2000)),
// und die „Ewig"-Liste ist nicht mehr durch das 2000-Doc-Fenster abgeschnitten.
//
// Hinweis: Deckt die All-Time-Liste ab. Für die Zeitfenster (heute/Woche/Monat)
// bräuchte es zusätzliche Bucket-Docs (z. B. leaderboard_daily/{yyyymmdd}/{uid});
// bewusst als Folgeschritt offen gelassen.
// ---------------------------------------------------------------------------
exports.aggregateScore = onDocumentCreated('scores/{sessionId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  if (!data) return;

  const uid = data.uid;
  const points = Number(data.scorePoints) || 0;
  if (!uid || points < 0) return;

  await db.collection('leaderboard_totals').doc(uid).set(
    {
      uid,
      displayName: data.displayName || 'Anonym',
      totalScorePoints: FieldValue.increment(points),
      gamesPlayed: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
});

// ---------------------------------------------------------------------------
// H3: Duell-Gewinner server-autoritativ ableiten. Sobald ein Duell auf
// 'completed' wechselt und ein opponentResult vorliegt, wird winnerUid aus den
// gemeldeten Zeiten neu bestimmt und ggf. korrigiert. In Kombination mit einer
// Rule, die client-gesetztes winnerUid verbietet, kann der Gegner den Sieger
// dann nicht mehr frei wählen.
//
// Bekannte Grenze: opponentResult.totalMs bleibt client-gemessen — eine absurd
// niedrige Zeit ist damit weiterhin möglich. Vollständig fälschungssicher wäre
// nur eine server-getimte Runde; bewusst nicht umgesetzt (privates 1v1-Feature
// ohne Geld-/Ranglisten-Wert).
// ---------------------------------------------------------------------------
exports.finalizeDuel = onDocumentUpdated('duels/{duelId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if (after.status !== 'completed') return;
  if (before.status === 'completed') return; // bereits final

  const opp = after.opponentResult;
  const chal = after.challengerResult;
  if (!opp || !chal) return;

  const oppMs = Number(opp.totalMs);
  const chalMs = Number(chal.totalMs);
  if (!Number.isFinite(oppMs) || !Number.isFinite(chalMs)) return;

  // Gleichstand → Challenger (war zuerst) — identisch zur Client-Logik.
  const correctWinner =
    oppMs < chalMs ? after.opponentUid : after.challengerUid;
  if (after.winnerUid === correctWinner) return; // schon korrekt

  await event.data.after.ref.update({ winnerUid: correctWinner });
});
