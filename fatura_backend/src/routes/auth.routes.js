const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');

// @route   POST api/auth/register
// @desc    Register user with phone number
// @access  Public
router.post('/register', authController.register);

// @route   POST api/auth/verify-otp
// @desc    Verify OTP and create user session
// @access  Public
router.post('/verify-otp', authController.verifyOtp);

// @route   POST api/auth/login
// @desc    Login user with phone number (will trigger OTP)
// @access  Public
router.post('/login', authController.register);

// @route   POST api/auth/login-firebase
// @desc    Login with Firebase ID token, returns app JWT
// @access  Public
router.post('/login-firebase', authController.loginWithFirebase);

// NEW: Password-based endpoints
// @route   POST api/auth/register-password
// @desc    Register with email/phone + password
// @access  Public
router.post('/register-password', authController.registerWithPassword);

// @route   POST api/auth/login-password
// @desc    Login with identifier (email or phone) + password
// @access  Public
router.post('/login-password', authController.loginWithPassword);

module.exports = router;
