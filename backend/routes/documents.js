const express = require('express');
const Document = require('../models/Document');
const router = express.Router();

router.post('/', async (req, res) => {
  try {
    const { userId, fileName, filePath, documentText } = req.body;
    
    const document = new Document({
      userId,
      fileName,
      filePath,
      documentText,
      uploadedDate: new Date()
    });
    
    const savedDoc = await document.save();
    res.status(201).json(savedDoc);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/user/:userId', async (req, res) => {
  try {
    const documents = await Document.find({ userId: req.params.userId })
      .sort({ uploadedDate: -1 });
    res.json(documents);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


router.get('/:docId', async (req, res) => {
  try {
    const document = await Document.findById(req.params.docId);
    if (!document) {
      return res.status(404).json({ message: 'Document not found' });
    }
    res.json(document);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


router.put('/:docId', async (req, res) => {
  try {
    const updated = await Document.findByIdAndUpdate(
      req.params.docId,
      req.body,
      { new: true }
    );
    res.json(updated);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


router.delete('/:docId', async (req, res) => {
  try {
    await Document.findByIdAndDelete(req.params.docId);
    res.json({ message: 'Document deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
