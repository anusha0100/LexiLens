const express = require('express');
const DocumentTag = require('../models/DocumentTag');
const router = express.Router();

// Create tag
router.post('/', async (req, res) => {
  try {
    const { userId, tagName, color } = req.body;
    
    const tag = new DocumentTag({
      userId,
      tagName,
      color: color || '#FF0000'
    });
    
    const savedTag = await tag.save();
    res.status(201).json(savedTag);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get tags for user
router.get('/user/:userId', async (req, res) => {
  try {
    const tags = await DocumentTag.find({ userId: req.params.userId });
    res.json(tags);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Update tag
router.put('/:tagId', async (req, res) => {
  try {
    const updated = await DocumentTag.findByIdAndUpdate(
      req.params.tagId,
      req.body,
      { new: true }
    );
    res.json(updated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Delete tag
router.delete('/:tagId', async (req, res) => {
  try {
    await DocumentTag.findByIdAndDelete(req.params.tagId);
    res.json({ message: 'Tag deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
