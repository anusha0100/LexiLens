// routes/users.js
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Document = require('../models/Document');
const DocumentTag = require('../models/DocumentTag');
const UserSession = require('../models/UserSession');
const AppSetting = require('../models/AppSetting');

// Delete user account and all associated data
router.delete('/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log(`Starting account deletion for user: ${userId}`);

    // Delete all user's documents
    const documentsResult = await Document.deleteMany({ userId });
    console.log(`Deleted ${documentsResult.deletedCount} documents`);

    // Delete all user's tags
    const tagsResult = await DocumentTag.deleteMany({ userId });
    console.log(`Deleted ${tagsResult.deletedCount} tags`);

    // Delete all user's sessions
    const sessionsResult = await UserSession.deleteMany({ userId });
    console.log(`Deleted ${sessionsResult.deletedCount} sessions`);

    // Delete all user's settings
    const settingsResult = await AppSetting.deleteMany({ userId });
    console.log(`Deleted ${settingsResult.deletedCount} settings`);

    // Delete user profile if exists
    let userResult = { deletedCount: 0 };
    if (User) {
      userResult = await User.deleteMany({ userId });
      console.log(`Deleted ${userResult.deletedCount} user profiles`);
    }

    const totalDeleted = 
      documentsResult.deletedCount + 
      tagsResult.deletedCount + 
      sessionsResult.deletedCount + 
      settingsResult.deletedCount +
      userResult.deletedCount;

    console.log(`Account deletion completed. Total records deleted: ${totalDeleted}`);

    res.status(200).json({
      success: true,
      message: 'Account and all associated data deleted successfully',
      details: {
        documents: documentsResult.deletedCount,
        tags: tagsResult.deletedCount,
        sessions: sessionsResult.deletedCount,
        settings: settingsResult.deletedCount,
        users: userResult.deletedCount,
        total: totalDeleted
      }
    });
  } catch (error) {
    console.error('Error deleting user account:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete account',
      error: error.message
    });
  }
});

module.exports = router;