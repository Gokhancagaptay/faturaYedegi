const admin = require('firebase-admin');

const initializeFirebase = () => {
  // IMPORTANT: Place your 'serviceAccountKey.json' in this same 'config' directory.
  const serviceAccount = require('./serviceAccountKey.json');

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: 'yepyenifa.firebasestorage.app' // Firebase Console'dan bucket adınızı buraya ekleyin
    });

    // Firestore'un undefined alanları yok saymasını sağla
    const db = admin.firestore();
    db.settings({ ignoreUndefinedProperties: true });
  }
};

module.exports = initializeFirebase;
