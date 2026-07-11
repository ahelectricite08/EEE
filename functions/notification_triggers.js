const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { fcmChannelBlocks } = require('./notification_push');
const { _isUserAdmin } = require('./lib/admin_auth');
const {
  _sendFcm, _sendFcmToUser, _sendTeamDvcrNotification, _notifPref, _skipMentionPushForRecipient,
} = require('./lib/push_helpers');

// ── 1. Notification push quand un article est publié ─────────────────────────
exports.notifyArticlePublished = onDocumentWritten('articles/{id}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return; // suppression

  // Déclenche uniquement si on passe à 'published' (création ou depuis draft)
  const wasDraft    = !before || before.status !== 'published';
  const isPublished = after.status === 'published';
  if (!isPublished || !wasDraft) return;

  const db = getFirestore();
  await _sendFcm(db, {
    topic: 'dvcr_articles',
    notification: {
      title: '📰 Nouvelle actu DVCR',
      body:  after.title || 'Nouvel article publié',
    },
    data: {
      type:      'article',
      articleId: event.params.id,
    },
    ...fcmChannelBlocks('dvcr_articles'),
  }, 'article published');
});

// ── Notification PDF bénévoles (Team DVCR uniquement) ─────────────────────────
exports.notifyTeamDvcrPdfUpdated = onDocumentWritten('benevole_documents/{id}', async (event) => {
  const before = event.data?.before?.exists ? (event.data.before.data() || {}) : null;
  const after = event.data?.after?.exists ? (event.data.after.data() || {}) : null;
  if (!after) return;
  if (after.published === false) return;

  const isCreate = !before;
  const changed =
    isCreate
    || String(before.fileUrl || '') !== String(after.fileUrl || '')
    || String(before.title || '') !== String(after.title || '')
    || before.published === false;
  if (!changed) return;

  const db = getFirestore();
  const title = '📄 Nouveau script de match disponible';
  const body = (after.title && String(after.title).trim())
    ? `Nouveau script : ${String(after.title).trim()}`
    : 'Consulte le nouveau script dans l’espace bénévoles.';

  const messageBase = {
    notification: { title, body },
    data: {
      type: 'benevole_pdf',
      documentId: String(event.params.id || ''),
    },
    ...fcmChannelBlocks('dvcr_alerts'),
  };

  const sent = await _sendTeamDvcrNotification(
    db,
    messageBase,
    'team_dvcr pdf updated',
  );
  console.log(`[team_dvcr] notifyTeamDvcrPdfUpdated: ${sent} envoi(s)`);
});

exports.notifyChatMention = onDocumentCreated(
  'chat_salons/{salonId}/messages/{msgId}',
  async (event) => {
    const db   = getFirestore();
    const data = event.data?.data();
    if (!data) return;

    const mentionUids = data.mentionUids ?? [];
    if (!mentionUids.length) return;

    const senderName = [data.firstName, data.lastName].filter(Boolean).join(' ') || 'Quelqu\'un';
    const text       = (data.text ?? '').substring(0, 80);
    const messaging  = getMessaging();

    await Promise.allSettled(mentionUids.map(async (uid) => {
      if (uid === data.uid) return; // pas de notif à soi-même
      const userSnap = await db.collection('users').doc(uid).get();
      const udata = userSnap.data() ?? {};
      if (_skipMentionPushForRecipient(udata)) return;
      if (!_notifPref(udata, 'chatMention')) return;
      return _sendFcmToUser(
        db,
        udata,
        {
          notification: {
            title: `💬 ${senderName} t'a mentionné`,
            body:  text,
          },
          data: { type: 'chat_mention', salonId: event.params.salonId },
          ...fcmChannelBlocks('dvcr_alerts'),
        },
        `chat mention ${uid}`,
        { recipientUid: uid },
      );
    }));
  }
);

// ── Notification duel — alerte l'adversaire quand un duel est créé ───────────
exports.notifyDuelCreated = onDocumentCreated('prono_duels/{duelId}', async (event) => {
  const db   = getFirestore();
  const data = event.data?.data();
  if (!data) return;

  const opponentUid = data.opponentUid;
  const ownerName   = data.ownerName ?? 'Un supporter';
  if (!opponentUid) return;

  // Récupère le token FCM de l'adversaire
  const opponentSnap = await db.collection('users').doc(opponentUid).get();
  const odata = opponentSnap.data() ?? {};
  if (!_notifPref(odata, 'duelInvite')) return;

  try {
    await _sendFcmToUser(
      db,
      odata,
      {
        notification: {
          title: '⚔️ Défi prono',
          body:  `${ownerName} veut t’affronter en duel. Ouvre l’app pour répondre !`,
        },
        data: {
          type:    'duel',
          duelId:  event.params.duelId,
        },
        ...fcmChannelBlocks('dvcr_alerts'),
      },
      `duel created ${opponentUid}`,
      { recipientUid: opponentUid },
    );
    console.log(`Duel notif envoyée à ${opponentUid}`);
  } catch (e) {
    console.error('notifyDuelCreated:', e.message);
  }
});

// ── Demande d’ami — notifie le destinataire ───────────────────────────────────
exports.notifyFriendRequest = onDocumentCreated('friend_requests/{reqId}', async (event) => {
  const db = getFirestore();
  const data = event.data?.data();
  if (!data) return;
  if ((data.status || 'pending') !== 'pending') return;

  const toUid = data.toUid;
  const fromName = data.fromName || 'Un membre';
  if (!toUid) return;

  const userSnap = await db.collection('users').doc(toUid).get();
  const udata = userSnap.data() ?? {};
  if (!_notifPref(udata, 'friendRequest')) return;

  try {
    await _sendFcmToUser(
      db,
      udata,
      {
        notification: {
          title: '👋 Nouvelle demande d’ami',
          body: `${fromName} souhaite être ton ami sur DVCR.`,
        },
        data: {
          type: 'friend_request',
          requestId: String(event.params.reqId || ''),
          fromUid: String(data.fromUid || ''),
        },
        ...fcmChannelBlocks('dvcr_alerts'),
      },
      `friend request ${toUid}`,
      { recipientUid: toUid },
    );
    console.log(`Friend request notif → ${toUid}`);
  } catch (e) {
    console.error('notifyFriendRequest:', e.message);
  }
});

// ── Duel terminé — gagnant / perdant / match nul ─────────────────────────────
exports.notifyDuelResolved = onDocumentWritten('prono_duels/{duelId}', async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.data();
  if (!after) return;

  const prev = before?.status;
  const next = after.status;
  if (next !== 'won' && next !== 'draw') return;
  if (prev === 'won' || prev === 'draw') return;

  const messaging = getMessaging();
  const duelId = event.params.duelId;
  const label = (after.matchLabel || 'Duel prono').toString();
  const ownerUid = after.ownerUid;
  const oppUid = after.opponentUid;

  const db = getFirestore();

  async function sendOne(uid, title, body) {
    if (!uid) return;
    const snap = await db.collection('users').doc(uid).get();
    const udata = snap.data() ?? {};
    if (!_notifPref(udata, 'duelResult')) return;
    await _sendFcmToUser(
      db,
      udata,
      {
        notification: { title, body },
        data: {
          type: 'duel_result',
          duelId: String(duelId),
          matchLabel: String(label),
        },
        ...fcmChannelBlocks('dvcr_alerts'),
      },
      `duel resolved ${uid}`,
      { recipientUid: uid },
    );
  }

  try {
    if (next === 'draw') {
      await sendOne(ownerUid, '🤝 Duel nul', `${label} — égalité parfaite ou sans vainqueur.`);
      await sendOne(oppUid, '🤝 Duel nul', `${label} — égalité parfaite ou sans vainqueur.`);
      return;
    }
    const w = after.winnerUid;
    const wname = (after.winnerName || 'Gagnant').toString();
    const loserUid = w === ownerUid ? oppUid : ownerUid;
    await sendOne(w, '🏆 Duel gagné', `${label} — victoire pour toi !`);
    await sendOne(loserUid, '😅 Duel perdu', `${label} — ${wname} remporte ce duel.`);
  } catch (e) {
    console.error('notifyDuelResolved:', e.message);
  }
});

// ── Récap fin de match — notifie chaque pronostiqueur de son résultat ─────────
exports.notifyMatchRecap = onDocumentWritten('matches/{matchId}', async (event) => {
  const db     = getFirestore();
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return;

  // Déclenche seulement quand le match passe à 'finished'
  const wasFinished = before?.status === 'finished';
  const isFinished  = after.status === 'finished';
  if (!isFinished || wasFinished) return;

  const matchId   = event.params.matchId;
  const score1    = after.score1 ?? after.homeScore ?? null;
  const score2    = after.score2 ?? after.awayScore ?? null;
  if (score1 === null || score2 === null) return;

  const team1 = after.team1 ?? 'Eq. 1';
  const team2 = after.team2 ?? 'Eq. 2';

  // Récupère tous les pronos pour ce match (collection 'predictions', champs score1Pred/score2Pred)
  const pronosSnap = await db.collection('predictions')
    .where('matchId', '==', matchId)
    .get();

  if (pronosSnap.empty) return;

  const actualResult = score1 > score2 ? 'home' : score1 < score2 ? 'away' : 'draw';

  const messaging = getMessaging();
  const promises  = [];

  for (const doc of pronosSnap.docs) {
    const prono  = doc.data();
    const uid    = prono.uid;
    if (!uid) continue;

    const p1 = prono.score1Pred ?? null;
    const p2 = prono.score2Pred ?? null;
    if (p1 === null || p2 === null) continue;

    // Calcul du résultat
    const isExact   = p1 === score1 && p2 === score2;
    const pronoRes  = p1 > p2 ? 'home' : p1 < p2 ? 'away' : 'draw';
    const isCorrect = pronoRes === actualResult;

    const xpGained = isExact ? '+20 XP' : isCorrect ? '+8 XP' : '+0 XP';
    const emoji    = isExact ? '🎯' : isCorrect ? '✅' : '❌';
    const label    = isExact ? 'Score exact !' : isCorrect ? 'Bon résultat !' : 'Raté cette fois';

    // Récupère le token FCM
    const userSnap = await db.collection('users').doc(uid).get();
    const udata = userSnap.data() ?? {};
    if (!_notifPref(udata, 'pronoPointsRecap')) continue;

    promises.push(
      _sendFcmToUser(
        db,
        udata,
        {
          notification: {
            title: `${emoji} ${team1} ${score1}–${score2} ${team2}`,
            body:  `Ton prono : ${p1}–${p2} · ${label} · ${xpGained}`,
          },
          data: {
            type:    'match_recap',
            matchId,
          },
          ...fcmChannelBlocks('dvcr_alerts'),
        },
        `match recap ${uid}`,
        { recipientUid: uid },
      ).catch(e => console.error(`Recap notif failed for ${uid}:`, e.message))
    );
  }

  await Promise.allSettled(promises);
  console.log(`Match ${matchId} recap: ${promises.length} notification(s) envoyées`);
});

// ── 2. Nettoyage automatique des messages de chat (> 7 jours) ────────────────
exports.cleanOldChatMessages = onSchedule('every 24 hours', async () => {
  const db      = getFirestore();
  const cutoff  = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const snap    = await db.collection('chat')
    .where('createdAt', '<', Timestamp.fromDate(cutoff))
    .get();

  if (snap.empty) { console.log('Aucun message à supprimer'); return; }

  // Suppression par batch de 500 (limite Firestore)
  const chunks = [];
  for (let i = 0; i < snap.docs.length; i += 500) {
    chunks.push(snap.docs.slice(i, i + 500));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`Chat : ${snap.docs.length} message(s) supprimé(s) (> 7 jours)`);
});

// ── Nettoyage des salons live archivés après 7 jours ─────────────────────────
exports.cleanArchivedLiveSalons = onSchedule('every 24 hours', async () => {
  const db     = getFirestore();
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const snap   = await db.collection('chat_salons')
    .where('archived', '==', true)
    .where('archivedAt', '<', Timestamp.fromDate(cutoff))
    .get();

  if (snap.empty) { console.log('Aucun salon live à supprimer'); return; }

  for (const salonDoc of snap.docs) {
    // Supprimer les messages du sous-salon
    const msgs = await salonDoc.ref.collection('messages').get();
    const chunks = [];
    for (let i = 0; i < msgs.docs.length; i += 500) {
      chunks.push(msgs.docs.slice(i, i + 500));
    }
    for (const chunk of chunks) {
      const batch = db.batch();
      chunk.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
    await salonDoc.ref.delete();
    console.log(`Salon live supprimé : ${salonDoc.id} (${msgs.docs.length} messages)`);
  }
});
