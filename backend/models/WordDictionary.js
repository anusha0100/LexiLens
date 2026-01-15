const mongoose = require('mongoose');

const wordSchema = new mongoose.Schema({
  word: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  definition: {
    type: String
  },
  pronunciation: {
    type: String
  },
  partOfSpeech: {
    type: String
  },
  examples: [{
    type: String
  }],
  synonyms: [{
    type: String
  }],
  addedDate: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('WordDictionary', wordSchema);
