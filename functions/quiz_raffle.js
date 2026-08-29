'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { eligibleVotes, pickWinner, isPastEndsAt } = require('./lib/quiz_raffle_core');

function _rolesOf(userDoc) {
  if (!userDoc.exists) return [];
  const data = userDoc.data() || {};
  const out = [];
  if (typeof data.role === 'string' && data.role.trim()) {
    out.push(data.role.trim());
  }
  if (Array.isArray(data.roles)) {
    for (const r of data.roles) {
      const s = String(r || '').trim();
      if (s) out.push(s);
    }
  }
  return out;
}

function _canPilotQuiz(userDoc) {
  const roles = _rolesOf(userDoc);
  return (
    roles.includes('admin') ||
    roles.includes('community_manager') ||
    roles.includes('statisticien')
  );
}

async function _requireQuizOps(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  if (!_canPilotQuiz(userDoc)) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  return { db, uid: request.auth.uid };
}

function _quizIdFrom(data) {
  return String(data?.quizId || '').trim();
}

function _votesFromSnap(snap) {
  return snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      uid: String(d.uid || doc.id).trim(),
      id: doc.id,
      choiceIndex: d.choiceIndex,
      displayName: String(d.displayName || '').trim(),
    };
  });
}

/**
 * Transaction : lit le quiz + secret + votes, tire un gagnant parmi les bonnes
 * réponses, écrit status=drawn. Pas de gagnant fictif si personne n’a bon.
 */
async function performDraw(db, quizId, drawnBy) {
  const id = String(quizId || '').trim();
  if (!id) {
    throw new HttpsError('invalid-argument', 'quizId manquant');
  }
  const by = drawnBy === 'timer' ? 'timer' : 'manual';
  const quizRef = db.collection('quiz_raffles').doc(id);
  const secretRef = quizRef.collection('admin').doc('secret');
  const votesRef = quizRef.collection('votes');

  return db.runTransaction(async (tx) => {
    const quizSnap = await tx.get(quizRef);
    if (!quizSnap.exists) {
      throw new HttpsError('not-found', 'Quiz introuvable');
    }
    const quiz = quizSnap.data() || {};
    const status = String(quiz.status || '').trim();
    if (status === 'drawn') {
      return {
        alreadyDrawn: true,
        winnerUid: String(quiz.winnerUid || '').trim(),
        winnerName: String(quiz.winnerName || '').trim(),
        eligibleCount: Number(quiz.eligibleCount) || 0,
      };
    }
    if (status === 'closed') {
      throw new HttpsError(
        'failed-precondition',
        'Ce quiz a été annulé — pas de tirage',
      );
    }
    if (status !== 'open') {
      throw new HttpsError('failed-precondition', 'Le quiz n’est pas ouvert');
    }

    const secretSnap = await tx.get(secretRef);
    if (!secretSnap.exists) {
      throw new HttpsError('failed-precondition', 'Bonne réponse absente');
    }
    const secret = secretSnap.data() || {};
    const correctIndex = Number(secret.correctIndex);
    if (!Number.isInteger(correctIndex) || correctIndex < 0) {
      throw new HttpsError('failed-precondition', 'Index de bonne réponse invalide');
    }

    const votesSnap = await tx.get(votesRef);
    const votes = _votesFromSnap(votesSnap);
    const picked = pickWinner(votes, correctIndex);
    const eligibleNames = eligibleVotes(votes, correctIndex).map((v) => {
      const name = String(v.displayName || '').trim();
      return name || 'Membre';
    });
    const choices = Array.isArray(quiz.choices) ? quiz.choices : [];
    const correctLabel = String(choices[correctIndex] || '').trim();

    tx.set(
      quizRef,
      {
        status: 'drawn',
        active: true,
        winnerUid: picked.winnerUid,
        winnerName: picked.winnerName,
        eligibleCount: picked.eligibleCount,
        eligibleNames,
        drawnAt: FieldValue.serverTimestamp(),
        drawnBy: by,
        correctIndexPublic: correctIndex,
        correctLabelPublic: correctLabel,
        closedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      alreadyDrawn: false,
      winnerUid: picked.winnerUid,
      winnerName: picked.winnerName,
      eligibleCount: picked.eligibleCount,
    };
  });
}

async function drawExpiredOpenQuizzes(db) {
  const now = Date.now();
  const snap = await db.collection('quiz_raffles').where('status', '==', 'open').get();
  let n = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!isPastEndsAt(data.endsAt, now)) continue;
    try {
      await performDraw(db, doc.id, 'timer');
      n += 1;
    } catch (err) {
      console.error('tickQuizRaffles draw failed', doc.id, err);
    }
  }
  return n;
}

exports.drawQuizRaffle = onCall({ cors: true }, async (request) => {
  const { db } = await _requireQuizOps(request);
  const quizId = _quizIdFrom(request.data);
  return performDraw(db, quizId, 'manual');
});

exports.closeQuizRaffle = onCall({ cors: true }, async (request) => {
  const { db } = await _requireQuizOps(request);
  const quizId = _quizIdFrom(request.data);
  const quizSnap = await db.collection('quiz_raffles').doc(quizId).get();
  if (!quizSnap.exists) {
    throw new HttpsError('not-found', 'Quiz introuvable');
  }
  const endsAt = (quizSnap.data() || {}).endsAt;
  const by = isPastEndsAt(endsAt, Date.now()) ? 'timer' : 'manual';
  return performDraw(db, quizId, by);
});

// Nom distinct : tickquizraffles existe déjà en Cloud Run orphelin (409).
exports.tickOpenQuizRaffles = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'Europe/Paris',
  },
  async () => {
    const db = getFirestore();
    const n = await drawExpiredOpenQuizzes(db);
    if (n) console.log(`tickOpenQuizRaffles drawn=${n}`);
  },
);
