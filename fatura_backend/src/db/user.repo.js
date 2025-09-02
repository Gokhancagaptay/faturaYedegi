const admin = require('firebase-admin');

// Lazy loading: Firebase'i sadece gerektiğinde başlat
const getFirestore = () => {
  if (!admin.apps.length) {
    throw new Error('Firebase Admin SDK not initialized. Please call initializeFirebase() first.');
  }
  return admin.firestore();
};

const createUserProfile = async (uid, userData) => {
    try {
        const db = getFirestore();
        const usersCollection = db.collection('users');
        await usersCollection.doc(uid).set(userData, { merge: true });
        console.log(`User profile created in Firestore for UID: ${uid}`);
    } catch (error) {
        console.error('Error creating user profile in Firestore:', error);
        throw new Error('Could not create user profile.');
    }
};

const getUserProfile = async (uid) => {
    try {
        const db = getFirestore();
        const usersCollection = db.collection('users');
        const doc = await usersCollection.doc(uid).get();
        if (!doc.exists) {
            return null;
        }
        return { uid: doc.id, ...doc.data() };
    } catch (error) {
        console.error('Error getting user profile from Firestore:', error);
        throw new Error('Could not get user profile.');
    }
};

// NEW: Password-based users in app_users collection
const APP_USERS = 'app_users';

const findUserByEmailOrPhone = async (identifier) => {
  const db = getFirestore();
  const col = db.collection(APP_USERS);
  let query = col.where('email', '==', identifier).limit(1);
  let snap = await query.get();
  if (snap.empty) {
    query = col.where('phoneNumber', '==', identifier).limit(1);
    snap = await query.get();
  }
  if (snap.empty) return null;
  const doc = snap.docs[0];
  return { id: doc.id, ...doc.data() };
};

const createAppUser = async (user) => {
  const db = getFirestore();
  const col = db.collection(APP_USERS);
  const ref = await col.add(user);
  return { id: ref.id, ...user };
};

const updateAppUser = async (id, data) => {
  const db = getFirestore();
  await db.collection(APP_USERS).doc(id).update(data);
};

// NEW: Upsert mirror in top-level `users` collection (by app_users id)
const upsertUsersDoc = async (id, data) => {
  const db = getFirestore();
  await db.collection('users').doc(id).set(data, { merge: true });
};

// NEW: Ensure app_users document exists for invoice storage
const ensureAppUserExists = async (userId) => {
  try {
    const db = getFirestore();
    const userDoc = db.collection(APP_USERS).doc(userId);
    const doc = await userDoc.get();
    
    if (!doc.exists) {
      // Create minimal user document if it doesn't exist
      await userDoc.set({
        createdAt: new Date(),
        lastActivity: new Date()
      }, { merge: true });
      console.log(`Created app_users document for userId: ${userId}`);
    }
  } catch (error) {
    console.error('Error ensuring app_user exists:', error);
    // Don't throw error, just log it
  }
};

module.exports = {
    createUserProfile,
    getUserProfile,
    findUserByEmailOrPhone,
    createAppUser,
    updateAppUser,
    upsertUsersDoc,
    ensureAppUserExists,
};
