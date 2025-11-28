const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const userRepo = require('../db/user.repo');

const findOrCreateUser = async (phoneNumber) => {
    try {
        let user;
        try {
            user = await admin.auth().getUserByPhoneNumber(phoneNumber);
        } catch (error) {
            if (error.code === 'auth/user-not-found') {
                user = await admin.auth().createUser({
                    phoneNumber: phoneNumber,
                });
                await userRepo.createUserProfile(user.uid, { phoneNumber, createdAt: new Date() });
            } else {
                throw error;
            }
        }

        // JWT_SECRET kontrolü
        if (!process.env.JWT_SECRET) {
            throw new Error('JWT_SECRET environment variable is required');
        }
        const token = jwt.sign({ uid: user.uid, phoneNumber: user.phoneNumber }, process.env.JWT_SECRET, {
            expiresIn: '7d',
        });

        return { user, token };
    } catch (error) {
        console.error('Error in findOrCreateUser:', error);
        throw new Error('Failed to process user authentication.');
    }
};

// Password-based register
const registerWithPassword = async ({ name, email, phoneNumber, password }) => {
  const existing = await userRepo.findUserByEmailOrPhone(email || phoneNumber);
  if (existing) {
    throw new Error('User already exists');
  }
  const passwordHash = await bcrypt.hash(password, 10);
  const userDoc = await userRepo.createAppUser({
    name: name || '',
    email: email || null,
    phoneNumber: phoneNumber || null,
    passwordHash,
    createdAt: new Date(),
  });
  // Mirror to top-level users collection for unified view
  await userRepo.upsertUsersDoc(userDoc.id, {
    name: userDoc.name,
    email: userDoc.email,
    phoneNumber: userDoc.phoneNumber,
    createdAt: userDoc.createdAt,
    provider: 'password',
  });
  // JWT_SECRET kontrolü
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is required');
  }
  const token = jwt.sign({ id: userDoc.id, email: userDoc.email, phoneNumber: userDoc.phoneNumber }, process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
  return { user: userDoc, token };
};

// Password-based login
const loginWithPassword = async ({ identifier, password }) => {
  const user = await userRepo.findUserByEmailOrPhone(identifier);
  if (!user || !user.passwordHash) {
    throw new Error('Invalid credentials');
  }
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) throw new Error('Invalid credentials');
  // JWT_SECRET kontrolü
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is required');
  }
  const token = jwt.sign({ id: user.id, email: user.email, phoneNumber: user.phoneNumber }, process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
  // Ensure top-level users doc exists/updated
  await userRepo.upsertUsersDoc(user.id, {
    name: user.name || '',
    email: user.email || null,
    phoneNumber: user.phoneNumber || null,
    lastLoginAt: new Date(),
    provider: 'password',
  });
  return { user, token };
};

module.exports = {
    findOrCreateUser,
    registerWithPassword,
    loginWithPassword,
};

// Verify Firebase ID token and return our JWT
module.exports.loginWithFirebaseIdToken = async (firebaseIdToken, phoneNumberHint) => {
  try {
    const decoded = await admin.auth().verifyIdToken(firebaseIdToken);
    const uid = decoded.uid;
    let userRecord = await admin.auth().getUser(uid);

    if (!userRecord.phoneNumber && phoneNumberHint) {
      try {
        userRecord = await admin.auth().updateUser(uid, { phoneNumber: phoneNumberHint });
      } catch (_) {}
    }

    await userRepo.createUserProfile(uid, { phoneNumber: userRecord.phoneNumber || phoneNumberHint, updatedAt: new Date() });

    // JWT_SECRET kontrolü
    if (!process.env.JWT_SECRET) {
      throw new Error('JWT_SECRET environment variable is required');
    }
    const token = jwt.sign({ uid, phoneNumber: userRecord.phoneNumber || phoneNumberHint }, process.env.JWT_SECRET, {
      expiresIn: '7d',
    });
    return { user: { uid, phoneNumber: userRecord.phoneNumber || phoneNumberHint }, token };
  } catch (error) {
    console.error('Error verifying Firebase ID token:', error);
    throw error;
  }
};
