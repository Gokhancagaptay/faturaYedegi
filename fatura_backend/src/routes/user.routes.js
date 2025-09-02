const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');


const { protect } = require('../middlewares/auth.middleware');

// @route   GET api/user/profile
// @desc    Get user profile information
// @access  Private
router.get('/profile', protect, userController.getUserProfile);

// @route   PUT api/user/profile
// @desc    Update user profile information
// @access  Private
router.put('/profile', protect, userController.updateUserProfile);

module.exports = router;
