const { onDocumentCreated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { fcmChannelBlocks } = require('./notification_push');
const { _isUserAdmin } = require('./lib/admin_auth');
const {
  _sendFcm, _sendFcmToUser, _sendTeamDvcrNotification, _notifPref, _skipMentionPushForRecipient,
} = require('./lib/push_helpers');

function _articleNotifBody(after) {
  const excerpt = String(after.excerpt || '').replace(/\s+/g, ' ').trim();
  if (excerpt.length >= 24) {
    return excerpt.length > 140 ? `${excerpt.slice(0, 137)}…` : excerpt;
  }
  const content = String(after.content || '').replace(/\s+/g, ' ').trim();
  if (content.length >= 24) {
    return content.length > 140 ? `${content.slice(0, 137)}…` : content;
  }
  return 'À lire maintenant dans l’app DVCR.';
}

// ── 1. Notification push quand un article est publié ─────────────────────────
exports.notifyArticlePublished = onDocumentWritten('articles/{id}', async (event) => {
  const before = event.data?.before?.data();
  const after  = event.data?.after?.data();
  if (!after) return; // suppression

  // Déclenche uniquement si on passe à 'published' (création ou depuis draft)
  const wasDraft    = !before || before.status !== 'published';
  const isPublished = after.status === 'published';
  if (!isPublished || !wasDraft) return;
  if (after.notifSent === true) return;

  const db = getFirestore();
  const ref = event.data.after.ref;

  // Anti-double : le webhook Wix rejoue en merge — on réserve le crédit avant l’envoi.
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data() || {};
    if (d.notifSent === true) return false;
    if (d.status !== 'published') return false;
    tx.update(ref, {
      notifSent: true,
      notifSentAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!claimed) return;

  const title = String(after.title || '').trim() || 'Nouvelle actu DVCR';
  await _sendFcm(db, {
    topic: 'dvcr_articles',
    notification: {
      title: title.length > 80 ? `${title.slice(0, 77)}…` : title,
      body:  _articleNotifBody(after),
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

// Récap par match retiré (spam). Le récap journée vit dans
// functions/lib/prono_day_recap.js via calculatePronoPoints.

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
