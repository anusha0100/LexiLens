const mongoose = require('mongoose');

const tagSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  tagName: {
    type: String,
    required: true
  },
  color: {
    type: String,
    default: '#FF0000'
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

tagSchema.index({ userId: 1, tagName: 1 }, { unique: true });

module.exports = mongoose.model('DocumentTag', tagSchema);
