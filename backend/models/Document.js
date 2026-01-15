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
    required: true
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
  }
});

// Compound index for efficient queries
documentSchema.index({ userId: 1, uploadedDate: -1 });

module.exports = mongoose.model('Document', documentSchema);
