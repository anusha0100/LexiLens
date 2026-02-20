const express = require('express');
const router = express.Router();
const Document = require('../models/Document');
const DocumentTag = require('../models/DocumentTag');
const UserSession = require('../models/UserSession');
const AppSetting = require('../models/AppSetting');


router.delete('/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log(`Starting account deletion for user: ${userId}`);

    
    const documentsResult = await Document.deleteMany({ userId });
    console.log(`Deleted ${documentsResult.deletedCount} documents`);

    
    const tagsResult = await DocumentTag.deleteMany({ userId });
    console.log(`Deleted ${tagsResult.deletedCount} tags`);

    
    const sessionsResult = await UserSession.deleteMany({ userId });
    console.log(`Deleted ${sessionsResult.deletedCount} sessions`);

    
    const settingsResult = await AppSetting.deleteMany({ userId });
    console.log(`Deleted ${settingsResult.deletedCount} settings`);

    const totalDeleted = 
      documentsResult.deletedCount + 
      tagsResult.deletedCount + 
      sessionsResult.deletedCount + 
      settingsResult.deletedCount;

    console.log(`Account deletion completed. Total records deleted: ${totalDeleted}`);

    res.status(200).json({
      success: true,
      message: 'Account and all associated data deleted successfully',
      details: {
        documents: documentsResult.deletedCount,
        tags: tagsResult.deletedCount,
        sessions: sessionsResult.deletedCount,
        settings: settingsResult.deletedCount,
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