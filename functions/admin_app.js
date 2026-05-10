const { getApps, initializeApp } = require('firebase-admin/app');

const PROJECT_ID = 'drapeau-vert-app';

function initLocalAdminApp() {
  if (getApps().length > 0) {
    return getApps()[0];
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.warn(
      'GOOGLE_APPLICATION_CREDENTIALS n\'est pas defini. ' +
        'Les scripts locaux Firebase Admin peuvent echouer sans credentials ADC.'
    );
  }

  return initializeApp({ projectId: PROJECT_ID });
}

module.exports = {
  PROJECT_ID,
  initLocalAdminApp,
};
