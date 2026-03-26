const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  fileName: {
    type: String,
    required: true
  },
  filePath: {
    type: String,
    required: false,
    default: ''
  },
  fileSize: {
    type: Number
  },
  uploadedDate: {
    type: Date,
    default: Date.now,
    index: true
  },
  documentText: {
    type: String
  },
  tags: [{
    type: String
  }],
  isScanned: {
    type: Boolean,
    default: false
  },
  isFavorite: {
    type: Boolean,
    default: false
  },
  detectedLanguage: {
    type: String,
    default: null
  },
  detectedScript: {
    type: String,
    default: null
  }
});


documentSchema.index({ userId: 1, uploadedDate: -1 });

module.exports = mongoose.model('Document', documentSchema);