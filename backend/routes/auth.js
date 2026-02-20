// routes/auth.js
const express = require('express');
const router = express.Router();
const { sendPasswordResetEmail } = require('../services/emailService');
const crypto = require('crypto');

// Store reset tokens temporarily (in production, use Redis or database)
const resetTokens = new Map();

router.post('/request-reset', async (req, res) => {
  try {
    const { email } = req.body;
    
    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = Date.now() + 3600000; // 1 hour
    
    // Store token
    resetTokens.set(resetToken, {
      email,
      expiresAt
    });
    
    // Send email
    const result = await sendPasswordResetEmail(email, resetToken);
    
    if (result.success) {
      res.json({ success: true, message: 'Password reset email sent' });
    } else {
      res.status(500).json({ success: false, message: 'Failed to send email' });
    }
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/verify-reset-token', async (req, res) => {
  try {
    const { token } = req.body;
    
    const tokenData = resetTokens.get(token);
    
    if (!tokenData) {
      return res.status(400).json({ valid: false, message: 'Invalid token' });
    }
    
    if (Date.now() > tokenData.expiresAt) {
      resetTokens.delete(token);
      return res.status(400).json({ valid: false, message: 'Token expired' });
    }
    
    res.json({ valid: true, email: tokenData.email });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/reset-password', async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    
    const tokenData = resetTokens.get(token);
    
    if (!tokenData || Date.now() > tokenData.expiresAt) {
      return res.status(400).json({ success: false, message: 'Invalid or expired token' });
    }
    
    // Here you would update the password in Firebase
    // This needs to be done on the client side with Firebase Auth
    
    resetTokens.delete(token);
    res.json({ success: true, message: 'Password reset successful' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;