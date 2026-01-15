const mongoose = require('mongoose');

const settingSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  settingKey: {
    type: String,
    required: true
  },
  value: mongoose.Schema.Types.Mixed,
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

settingSchema.index({ settingKey: 1 }, { unique: false });

module.exports = mongoose.model('AppSetting', settingSchema);
