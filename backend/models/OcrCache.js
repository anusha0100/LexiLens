const mongoose = require('mongoose');

/**
 * OcrCache — stores recognised text keyed by a hash of the source image.
 *
 * Matches the SDS ER diagram fields:
 *   cache_id, image_hash, recognized_text, confidence_score,
 *   language_detected, processing_time_ms, created_at,
 *   last_accessed, access_count
 *
 * The Flutter OCRService checks this collection before running ML Kit so that
 * repeated scans of the same image skip full ML processing (cache hit).
 */
const ocrCacheSchema = new mongoose.Schema({
  // SHA-256 hex digest of the raw image bytes — used as the lookup key.
  imageHash: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },

  recognizedText: {
    type: String,
    required: true,
    default: '',
  },

  // 0.0 – 1.0 average confidence across all recognised blocks.
  confidenceScore: {
    type: Number,
    min: 0,
    max: 1,
    default: null,
  },

  // e.g. 'English', 'Hindi', 'French' — mirrors OCRService._detectLanguageFromText output.
  languageDetected: {
    type: String,
    default: 'Unknown',
  },

  // How long the ML Kit processing took in milliseconds.
  processingTimeMs: {
    type: Number,
    default: null,
  },

  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },

  lastAccessed: {
    type: Date,
    default: Date.now,
  },

  // Incremented each time this entry is returned as a cache hit.
  accessCount: {
    type: Number,
    default: 0,
  },
});

// TTL index: automatically evict cache entries after 30 days of non-access.
ocrCacheSchema.index({ lastAccessed: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 30 });

module.exports = mongoose.model('OcrCache', ocrCacheSchema);