const express = require('express');
const UserSession = require('../models/UserSession');
const router = express.Router();

// Create session
router.post('/', async (req, res) => {
  try {
    const { userId, token, deviceInfo, ipAddress } = req.body;
    
    const session = new UserSession({
      userId,
      token,
      deviceInfo,
      ipAddress,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    });
    
    const savedSession = await session.save();
    res.status(201).json(savedSession);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get active session for user
router.get('/:userId/active', async (req, res) => {
  try {
    const session = await UserSession.findOne({
      userId: req.params.userId,
      isActive: true,
      expiresAt: { $gt: new Date() }
    });
    
    if (!session) {
      return res.status(404).json({ message: 'No active session found' });
    }
    
    res.json(session);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Invalidate session
router.delete('/:sessionId', async (req, res) => {
  try {
    await UserSession.findByIdAndUpdate(req.params.sessionId, {
      isActive: false
    });
    res.json({ message: 'Session invalidated' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
