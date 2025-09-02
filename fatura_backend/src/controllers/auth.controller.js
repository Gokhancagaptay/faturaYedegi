const authService = require('../services/auth.service');

// A temporary in-memory store for OTPs. 
// In a production environment, use Redis or a similar caching service.
const otpStore = {}; 

const register = async (req, res) => {
    const { phoneNumber } = req.body;
    if (!phoneNumber) {
        return res.status(400).json({ message: 'Phone number is required.' });
    }

    try {
        // Generate a 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Store the OTP with the phone number, with a 5-minute expiry
        otpStore[phoneNumber] = { otp, expires: Date.now() + 300000 };

        console.log(`OTP for ${phoneNumber} is: ${otp}`); // Log OTP for testing

        res.status(200).json({ message: 'OTP sent successfully. Please verify.' });
    } catch (error) {
        res.status(500).json({ message: 'Error during registration process.', error: error.message });
    }
};

// Deprecated in favor of Firebase Phone Auth. Kept for compatibility if needed.
const verifyOtp = async (req, res) => {
    return res.status(410).json({ message: 'Legacy OTP verification disabled. Use /api/auth/login-firebase.' });
};

// New: login with Firebase ID token
const loginWithFirebase = async (req, res) => {
    const { firebaseIdToken, phoneNumber } = req.body;
    if (!firebaseIdToken) {
        return res.status(400).json({ message: 'firebaseIdToken is required.' });
    }
    try {
        const { user, token } = await authService.loginWithFirebaseIdToken(firebaseIdToken, phoneNumber);
        res.status(200).json({
            message: 'Login successful',
            user: { uid: user.uid, phoneNumber: user.phoneNumber },
            token
        });
    } catch (error) {
        res.status(401).json({ message: 'Invalid Firebase token', error: error.message });
    }
};

// NEW: Password-based register
const registerWithPassword = async (req, res) => {
  const { name, email, phoneNumber, password } = req.body;
  if ((!email && !phoneNumber) || !password) {
    return res.status(400).json({ message: 'Email or phone and password are required.' });
  }
  try {
    const { user, token } = await authService.registerWithPassword({ name, email, phoneNumber, password });
    res.status(201).json({ message: 'Registered', user, token });
  } catch (e) {
    res.status(400).json({ message: e.message || 'Registration failed' });
  }
};

// NEW: Password-based login
const loginWithPassword = async (req, res) => {
  const { identifier, password } = req.body; // identifier = email OR phoneNumber
  if (!identifier || !password) {
    return res.status(400).json({ message: 'Identifier and password are required.' });
  }
  try {
    const { user, token } = await authService.loginWithPassword({ identifier, password });
    res.status(200).json({ message: 'Login successful', user, token });
  } catch (e) {
    res.status(401).json({ message: e.message || 'Invalid credentials' });
  }
};

module.exports = {
    register,
    verifyOtp,
    loginWithFirebase,
    registerWithPassword,
    loginWithPassword,
};
