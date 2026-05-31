/**
 * Active la bannière « mise à jour recommandée » (latestBuild > build installé).
 * Usage: node scripts/patch-app-version-banner.js
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: 'drapeau-vert-app',
});

const LATEST_ANDROID = 20;
const LATEST_IOS = 20;

async function main() {
  const ref = getFirestore().collection('app_config').doc('app_version');
  await ref.set(
    {
      enabled: true,
      latestBuildAndroid: LATEST_ANDROID,
      latestBuildIos: LATEST_IOS,
      titleOptional: 'Nouvelle version DVCR',
      messageOptional:
        'Une mise à jour est disponible sur le store. Installe-la pour profiter des dernières améliorations.',
      updatedAt: new Date(),
    },
    { merge: true },
  );
  const snap = await ref.get();
  console.log('app_version mis à jour:', JSON.stringify(snap.data(), null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
