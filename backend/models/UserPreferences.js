const mongoose = require('mongoose');

/**
 * UserPreferences — typed, per-user preferences document.
 *
 * Matches the SDS ER diagram which specifies a dedicated UserPreferences
 * table with explicit typed columns rather than a generic key-value store.
 *
 * Fields defined here:
 *   font_type, font_size, theme_mode, overlay_opacity,
 *   speech_rate, preferred_voice, preferred_language,
 *   reading_ruler_enabled, syllable_breakdown_enabled, auto_zoom_level
 *
 * One document per user; upserted on first registration via the
 * /api/settings/seed-defaults/:userId route.
 */
const userPreferencesSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },

    // ── Typography ──────────────────────────────────────────────────────────
    fontType: {
      type: String,
      enum: ['OpenDyslexic', 'NotoSansDevanagari', 'Default'],
      default: 'OpenDyslexic',
    },

    fontSize: {
      type: Number,
      min: 10,
      max: 36,
      default: 14,
    },

    // ── Display ─────────────────────────────────────────────────────────────
    themeMode: {
      type: String,
      enum: ['light', 'dark', 'system'],
      default: 'light',
    },

    overlayOpacity: {
      type: Number,
      min: 0.0,
      max: 1.0,
      default: 0.7,
    },

    autoZoomLevel: {
      type: Number,
      min: 1.0,
      max: 5.0,
      default: 1.0,
    },

    // ── Text-to-Speech ───────────────────────────────────────────────────────
    speechRate: {
      type: Number,
      min: 0.1,
      max: 2.0,
      default: 0.5,
    },

    preferredVoice: {
      type: String,
      default: null,
    },

    preferredLanguage: {
      type: String,
      default: 'en-US',
    },

    // ── Reading Aids ─────────────────────────────────────────────────────────
    readingRulerEnabled: {
      type: Boolean,
      default: false,
    },

    syllableBreakdownEnabled: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true, // adds createdAt + updatedAt automatically
  }
);

module.exports = mongoose.model('UserPreferences', userPreferencesSchema);