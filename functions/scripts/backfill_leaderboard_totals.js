'use strict';

// Einmaliges, idempotentes Backfill von `leaderboard_totals` aus `scores`.
//
// Warum: `aggregateScore` (index.js) triggert nur onCreate — nach dem Deploy
// enthält `leaderboard_totals` daher nur NEUE Scores. Damit die „Ewig"-Liste
// nach der Client-Umstellung nicht auf Post-Deploy-Punkte schrumpft, füllt
// dieses Skript die bestehende Historie einmalig nach.
//
// WICHTIG: schreibt ABSOLUTE Summen mit .set({ merge: true }) — NICHT
// FieldValue.increment. Dadurch ist es gefahrlos wiederholbar: ein Re-Run
// überschreibt mit denselben Werten und akkumuliert nichts.
//
// Reihenfolge: erst `firebase deploy --only functions`, dann dieses Skript
// zuletzt laufen lassen. Sollte zwischen Read und Trigger genau ein Score
// entstehen, kann er einmalig vom Trigger UND vom Backfill gezählt werden
// (≤ wenige Punkte Drift) — ein erneuter Lauf bei ruhigem Traffic gleicht das ab.
//
// Lauf gegen Prod:
//   cd functions && npm install
//   # Auth: GOOGLE_APPLICATION_CREDENTIALS=pfad/zu/serviceAccount.json
//   #   (oder `firebase login` + Application Default Credentials)
//   node scripts/backfill_leaderboard_totals.js
//
// Lauf gegen den Emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 \
//     node scripts/backfill_leaderboard_totals.js

const { initializeApp } = require('firebase-admin/app');
const {
  getFirestore,
  FieldValue,
  FieldPath,
} = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

const PAGE = 500; // Lesefenster pro Seite
const BATCH = 500; // Firestore-Batch-Limit pro Commit

// Liest ALLE scores paginiert (über die 2000, die der Client kappt, hinaus) und
// faltet sie pro uid: absolute Punktesumme, Spielzahl und der Anzeigename vom
// jüngsten Score (nach finishedAt) — konsistent zum merge-most-recent-name der
// aggregateScore-Function. Gleiche Guards wie dort: !uid bzw. points < 0 raus.
async function readAllScores() {
  const totals = new Map();
  let last = null;
  let scanned = 0;

  for (;;) {
    let q = db.collection('scores').orderBy(FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned++;
      const d = doc.data();
      const uid = d.uid;
      const points = Number(d.scorePoints) || 0;
      if (!uid || points < 0) continue;

      const fin = d.finishedAt;
      const finMs =
        fin && typeof fin.toMillis === 'function' ? fin.toMillis() : 0;

      const cur = totals.get(uid) || {
        uid,
        displayName: 'Anonym',
        totalScorePoints: 0,
        gamesPlayed: 0,
        latestMs: -1,
      };
      cur.totalScorePoints += points;
      cur.gamesPlayed += 1;
      if (finMs >= cur.latestMs) {
        cur.latestMs = finMs;
        cur.displayName = (d.displayName && String(d.displayName)) || 'Anonym';
      }
      totals.set(uid, cur);
    }

    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  return { totals, scanned };
}

async function writeTotals(totals) {
  const entries = [...totals.values()];
  let written = 0;
  for (let i = 0; i < entries.length; i += BATCH) {
    const batch = db.batch();
    for (const e of entries.slice(i, i + BATCH)) {
      batch.set(
        db.collection('leaderboard_totals').doc(e.uid),
        {
          uid: e.uid,
          displayName: e.displayName,
          totalScorePoints: e.totalScorePoints,
          gamesPlayed: e.gamesPlayed,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      written++;
    }
    await batch.commit();
  }
  return written;
}

async function main() {
  console.log('Backfill leaderboard_totals: lese scores …');
  const { totals, scanned } = await readAllScores();
  console.log(
    `  ${scanned} Score-Docs gelesen, ${totals.size} Spieler aggregiert.`,
  );
  const written = await writeTotals(totals);
  console.log(
    `Fertig: ${written} leaderboard_totals-Docs geschrieben (absolut, merge).`,
  );
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error('Backfill fehlgeschlagen:', err);
    process.exit(1);
  },
);
