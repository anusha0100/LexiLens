const express = require('express');
const OcrCache = require('../models/OcrCache');
const router = express.Router();

// ── GET /api/ocr-cache/:imageHash ────────────────────────────────────────────
// Cache hit: return cached OCR result and bump access statistics.
router.get('/:imageHash', async (req, res) => {
  try {
    const entry = await OcrCache.findOne({ imageHash: req.params.imageHash });
    if (!entry) {
      return res.status(404).json({ success: false, hit: false });
    }

    // Update access metadata.
    entry.lastAccessed = new Date();
    entry.accessCount += 1;
    await entry.save();

    res.json({
      success: true,
      hit: true,
      recognizedText:   entry.recognizedText,
      confidenceScore:  entry.confidenceScore,
      languageDetected: entry.languageDetected,
      processingTimeMs: entry.processingTimeMs,
      accessCount:      entry.accessCount,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ── POST /api/ocr-cache ───────────────────────────────────────────────────────
// Cache miss: store the result of a fresh ML Kit recognition pass.
router.post('/', async (req, res) => {
  try {
    const {
      imageHash,
      recognizedText,
      confidenceScore,
      languageDetected,
      processingTimeMs,
    } = req.body;

    if (!imageHash || recognizedText === undefined) {
      return res.status(400).json({
        success: false,
        message: 'imageHash and recognizedText are required',
      });
    }

    // Upsert so duplicate hashes don't throw a duplicate-key error.
    const entry = await OcrCache.findOneAndUpdate(
      { imageHash },
      {
        $set: {
          recognizedText,
          confidenceScore:  confidenceScore  ?? null,
          languageDetected: languageDetected ?? 'Unknown',
          processingTimeMs: processingTimeMs ?? null,
          lastAccessed:     new Date(),
        },
        $setOnInsert: {
          imageHash,
          createdAt:   new Date(),
          accessCount: 0,
        },
      },
      { upsert: true, new: true }
    );

    res.status(201).json({ success: true, entry });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ── DELETE /api/ocr-cache/:imageHash ─────────────────────────────────────────
router.delete('/:imageHash', async (req, res) => {
  try {
    const result = await OcrCache.deleteOne({ imageHash: req.params.imageHash });
    res.json({ success: true, deleted: result.deletedCount > 0 });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;