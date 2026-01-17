const express = require('express');
const WordDictionary = require('../models/WordDictionary');
const router = express.Router();


router.get('/:word', async (req, res) => {
  try {
    const word = await WordDictionary.findOne({
      word: req.params.word.toLowerCase()
    });
    
    if (!word) {
      return res.status(404).json({ message: 'Word not found' });
    }
    
    res.json(word);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


router.get('/search/:query', async (req, res) => {
  try {
    const words = await WordDictionary.find({
      word: { $regex: req.params.query, $options: 'i' }
    }).limit(10);
    
    res.json(words);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


router.post('/', async (req, res) => {
  try {
    const wordData = new WordDictionary(req.body);
    const saved = await wordData.save();
    res.status(201).json(saved);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
