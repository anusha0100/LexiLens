const mongoose = require('mongoose');

/**
 * Document — persisted scan / uploaded-PDF record.
 *
 * Adds the three fields that were present in the SDS full ER diagram
 * but missing from the original implementation:
 *   • imageFormat       — e.g. 'jpg', 'png'
 *   • ocrConfidence     — 0.0–1.0 average ML Kit confidence for this scan
 *   • processingTimeMs  — wall-clock time the OCR pipeline took
 */
const documentSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true,
  },

  fileName: {
    type: String,
    required: true,
  },

  filePath: {
    type: String,
    required: false,
    default: '',
  },

  fileSize: {
    type: Number,
  },

  uploadedDate: {
    type: Date,
    default: Date.now,
    index: true,
  },

  documentText: {
    type: String,
  },

  tags: [{ type: String }],

  isScanned: {
    type: Boolean,
    default: false,
  },

  isFavorite: {
    type: Boolean,
    default: false,
  },

  detectedLanguage: {
    type: String,
    default: null,
  },

  detectedScript: {
    type: String,
    default: null,
  },

  // ── Fields added to match SDS ER diagram ──────────────────────────────────

  // MIME sub-type of the source image, e.g. 'jpeg', 'png', 'webp'.
  imageFormat: {
    type: String,
    default: null,
  },

  // Average ML Kit confidence score across all recognised text blocks (0–1).
  ocrConfidence: {
    type: Number,
    min: 0,
    max: 1,
    default: null,
  },

  // Wall-clock milliseconds taken by the OCR pipeline for this document.
  processingTimeMs: {
    type: Number,
    default: null,
  },
});

documentSchema.index({ userId: 1, uploadedDate: -1 });

module.exports = mongoose.model('Document', documentSchema);