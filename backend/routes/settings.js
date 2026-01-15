const express = require('express');
const AppSetting = require('../models/AppSetting');
const router = express.Router();

// Save/Update setting
router.post('/', async (req, res) => {
  try {
    const { userId, settingKey, value } = req.body;
    
    let setting = await AppSetting.findOne({ userId, settingKey });
    
    if (setting) {
      setting.value = value;
      setting.updatedAt = new Date();
    } else {
      setting = new AppSetting({
        userId,
        settingKey,
        value,
        updatedAt: new Date()
      });
    }
    
    const saved = await setting.save();
    res.status(201).json(saved);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get setting
router.get('/:userId/:settingKey', async (req, res) => {
  try {
    const setting = await AppSetting.findOne({
      userId: req.params.userId,
      settingKey: req.params.settingKey
    });
    
    res.json(setting || { value: null });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get all settings for user
router.get('/user/:userId', async (req, res) => {
  try {
    const settings = await AppSetting.find({ userId: req.params.userId });
    res.json(settings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
