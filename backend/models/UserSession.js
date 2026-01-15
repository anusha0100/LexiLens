const mongoose = require('mongoose');

const userSessionSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  token: {
    type: String,
    required: true
  },
  deviceInfo: {
    type: String,
    default: 'Unknown Device'
  },
  ipAddress: {
    type: String,
    default: 'N/A'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  expiresAt: {
    type: Date,
    default: () => new Date(+new Date() + 30 * 24 * 60 * 60 * 1000),
    index: true
  },
  isActive: {
    type: Boolean,
    default: true
  }
});

module.exports = mongoose.model('UserSession', userSessionSchema);
