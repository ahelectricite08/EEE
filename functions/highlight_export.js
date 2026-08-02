const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { _isUserAdmin } = require('./lib/admin_auth');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const ffmpegPath = require('ffmpeg-static');

const STINGER_DOC = 'app_config/highlight_stingers';
const MAX_CLIPS = 24;

function _rolesOf(userDoc) {
  if (!userDoc.exists) return [];
  const d = userDoc.data() || {};
  const roles = Array.isArray(d.roles) ? d.roles.map(String) : [];
  if (d.role) roles.push(String(d.role));
  return roles.map((r) => r.trim().toLowerCase());
}

async function _requireMatchStaff(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Non authentifié');
  }
  const db = getFirestore();
  const userDoc = await db.collection('users').doc(request.auth.uid).get();
  const roles = _rolesOf(userDoc);
  const ok =
    _isUserAdmin(userDoc) ||
    roles.includes('community_manager') ||
    roles.includes('statisticien');
  if (!ok) {
    throw new HttpsError('permission-denied', 'Accès refusé');
  }
  return { db, uid: request.auth.uid };
}

function _run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let err = '';
    child.stderr.on('data', (d) => {
      err += d.toString();
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(err.slice(-2000) || `ffmpeg exit ${code}`));
    });
  });
}

async function _downloadToFile(file, dest) {
  await file.download({ destination: dest });
}

/** Normalise un clip en H264/AAC 720p pour concat fiable. */
async function _normalize(inputPath, outputPath) {
  await _run(ffmpegPath, [
    '-y',
    '-i',
    inputPath,
    '-vf',
    'scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-crf',
    '23',
    '-c:a',
    'aac',
    '-b:a',
    '128k',
    '-ar',
    '44100',
    '-ac',
    '2',
    '-movflags',
    '+faststart',
    outputPath,
  ]);
}

async function _concatList(listPath, outputPath) {
  await _run(ffmpegPath, [
    '-y',
    '-f',
    'concat',
    '-safe',
    '0',
    '-i',
    listPath,
    '-c',
    'copy',
    '-movflags',
    '+faststart',
    outputPath,
  ]);
}

/**
 * Exporte le résumé MP4 d’un match : highlights chronologiques + stinger entre chaque.
 * data: { matchId, stingerId? }
 */
exports.exportMatchHighlightResume = onCall(
  {
    cors: true,
    region: 'europe-west1',
    timeoutSeconds: 540,
    memory: '2GiB',
  },
  async (request) => {
    const { db, uid } = await _requireMatchStaff(request);
    const matchId = String(request.data?.matchId || '').trim();
    if (!matchId) {
      throw new HttpsError('invalid-argument', 'matchId requis');
    }

    const matchRef = db.collection('matches').doc(matchId);
    const matchSnap = await matchRef.get();
    if (!matchSnap.exists) {
      throw new HttpsError('not-found', 'Match introuvable');
    }

    await matchRef.set(
      {
        highlightExport: {
          status: 'processing',
          updatedAt: FieldValue.serverTimestamp(),
          requestedBy: uid,
        },
      },
      { merge: true },
    );

    const highlightsSnap = await matchRef.collection('highlights').get();
    const clips = highlightsSnap.docs
      .map((d) => ({ id: d.id, ...(d.data() || {}) }))
      .filter((c) => c.status === 'ready' && String(c.videoUrl || '').trim())
      .sort((a, b) => {
        const m = (Number(a.minute) || 0) - (Number(b.minute) || 0);
        if (m !== 0) return m;
        return String(a.eventId || a.id).localeCompare(String(b.eventId || b.id));
      })
      .slice(0, MAX_CLIPS);

    if (clips.length === 0) {
      await matchRef.set(
        {
          highlightExport: {
            status: 'failed',
            error: 'Aucun clip highlight prêt',
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      throw new HttpsError('failed-precondition', 'Aucun clip highlight prêt');
    }

    const stingerDoc = await db.doc(STINGER_DOC).get();
    const stingerData = stingerDoc.data() || {};
    const items = Array.isArray(stingerData.items) ? stingerData.items : [];
    const wantedId = String(
      request.data?.stingerId || stingerData.selectedId || '',
    ).trim();
    let stinger = items.find((i) => String(i.id) === wantedId);
    if (!stinger && items.length) stinger = items[0];
    if (!stinger || !String(stinger.storagePath || stinger.url || '').trim()) {
      await matchRef.set(
        {
          highlightExport: {
            status: 'failed',
            error: 'Aucun stinger configuré',
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      throw new HttpsError(
        'failed-precondition',
        'Configure un stinger dans l’admin avant d’exporter',
      );
    }

    const bucket = getStorage().bucket();
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'dvcr-resume-'));
    const normalized = [];

    try {
      // Stinger
      const stingerLocal = path.join(workDir, 'stinger_src.mp4');
      const stingerNorm = path.join(workDir, 'stinger_n.mp4');
      if (stinger.storagePath) {
        await _downloadToFile(bucket.file(stinger.storagePath), stingerLocal);
      } else {
        // URL publique Storage — download via https not available easily; require storagePath
        throw new HttpsError(
          'failed-precondition',
          'Stinger sans storagePath — ré-uploade le stinger',
        );
      }
      await _normalize(stingerLocal, stingerNorm);

      for (let i = 0; i < clips.length; i++) {
        const c = clips[i];
        const src = path.join(workDir, `clip_${i}_src.mp4`);
        const out = path.join(workDir, `clip_${i}_n.mp4`);
        const storagePath = String(c.storagePath || '').trim();
        if (!storagePath) {
          throw new HttpsError(
            'failed-precondition',
            `Clip ${c.eventId || c.id} sans storagePath`,
          );
        }
        await _downloadToFile(bucket.file(storagePath), src);
        await _normalize(src, out);
        normalized.push(out);
      }

      // Ordre : clip, stinger, clip, stinger, … clip (pas de stinger après le dernier)
      const sequence = [];
      for (let i = 0; i < normalized.length; i++) {
        sequence.push(normalized[i]);
        if (i < normalized.length - 1) sequence.push(stingerNorm);
      }

      const listPath = path.join(workDir, 'list.txt');
      const listBody = sequence
        .map((p) => `file '${p.replace(/\\/g, '/').replace(/'/g, "'\\''")}'`)
        .join('\n');
      fs.writeFileSync(listPath, listBody, 'utf8');

      const outLocal = path.join(workDir, 'resume.mp4');
      await _concatList(listPath, outLocal);

      const ts = Date.now();
      const destPath = `match_highlights/${matchId}/exports/resume_${ts}.mp4`;
      const destFile = bucket.file(destPath);
      await destFile.save(fs.readFileSync(outLocal), {
        contentType: 'video/mp4',
        metadata: {
          metadata: {
            matchId,
            stingerId: String(stinger.id || ''),
            clipCount: String(clips.length),
            exportedBy: uid,
          },
        },
      });
      await destFile.makePublic().catch(() => {});
      const [signedUrl] = await destFile
        .getSignedUrl({
          action: 'read',
          expires: Date.now() + 1000 * 60 * 60 * 24 * 7,
        })
        .catch(() => [null]);
      const publicUrl =
        signedUrl ||
        `https://storage.googleapis.com/${bucket.name}/${destPath}`;

      const payload = {
        status: 'ready',
        url: publicUrl,
        storagePath: destPath,
        clipCount: clips.length,
        stingerId: String(stinger.id || ''),
        stingerName: String(stinger.name || ''),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        requestedBy: uid,
      };
      await matchRef.set({ highlightExport: payload }, { merge: true });
      return {
        ok: true,
        url: publicUrl,
        storagePath: destPath,
        clipCount: clips.length,
        stingerId: stinger.id,
      };
    } catch (e) {
      console.error('[exportMatchHighlightResume]', e);
      await matchRef.set(
        {
          highlightExport: {
            status: 'failed',
            error: (e && e.message) || String(e),
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        { merge: true },
      );
      if (e instanceof HttpsError) throw e;
      throw new HttpsError('internal', e.message || 'Export échoué');
    } finally {
      try {
        fs.rmSync(workDir, { recursive: true, force: true });
      } catch (_) {}
    }
  },
);
