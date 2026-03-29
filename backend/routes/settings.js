const express = require('express');
const AppSetting = require('../models/AppSetting');
const UserPreferences = require('../models/UserPreferences');
const router = express.Router();

// ── Validation rules (implements SDS process 5.5 — Validate Config) ─────────
const PREFERENCE_RULES = {
  fontType:                 { type: 'string',  enum: ['OpenDyslexic', 'NotoSansDevanagari', 'Default'] },
  fontSize:                 { type: 'number',  min: 10, max: 36 },
  themeMode:                { type: 'string',  enum: ['light', 'dark', 'system'] },
  overlayOpacity:           { type: 'number',  min: 0.0, max: 1.0 },
  autoZoomLevel:            { type: 'number',  min: 1.0, max: 5.0 },
  speechRate:               { type: 'number',  min: 0.1, max: 2.0 },
  preferredVoice:           { type: 'string'  },
  preferredLanguage:        { type: 'string'  },
  readingRulerEnabled:      { type: 'boolean' },
  syllableBreakdownEnabled: { type: 'boolean' },
};

/**
 * Validate a single preference key/value pair against PREFERENCE_RULES.
 * Returns null on success, or an error string on failure.
 */
function validatePreference(key, value) {
  const rule = PREFERENCE_RULES[key];
  // Keys not in the typed preference set are passed through without validation.
  if (!rule) return null;

  if (rule.type === 'number') {
    const n = Number(value);
    if (isNaN(n)) return `${key} must be a number`;
    if (rule.min !== undefined && n < rule.min) return `${key} must be >= ${rule.min}`;
    if (rule.max !== undefined && n > rule.max) return `${key} must be <= ${rule.max}`;
  }

  if (rule.type === 'boolean') {
    if (typeof value !== 'boolean' && value !== 'true' && value !== 'false') {
      return `${key} must be a boolean`;
    }
  }

  if (rule.type === 'string') {
    if (typeof value !== 'string') return `${key} must be a string`;
    if (rule.enum && !rule.enum.includes(value)) {
      return `${key} must be one of: ${rule.enum.join(', ')}`;
    }
  }

  return null;
}

// ── Default preference values (implements SDS D2 — Default Settings store) ──
const DEFAULT_PREFERENCES = {
  fontType:                 'OpenDyslexic',
  fontSize:                 14,
  themeMode:                'light',
  overlayOpacity:           0.7,
  autoZoomLevel:            1.0,
  speechRate:               0.5,
  preferredVoice:           null,
  preferredLanguage:        'en-US',
  readingRulerEnabled:      false,
  syllableBreakdownEnabled: false,
};

// ── POST /api/settings/seed-defaults/:userId ─────────────────────────────────
// Called once after successful registration to populate typed UserPreferences
// and write the same defaults into the generic AppSetting store so existing
// reads continue to work.
router.post('/seed-defaults/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    // Upsert the typed UserPreferences document.
    await UserPreferences.findOneAndUpdate(
      { userId },
      { $setOnInsert: { userId, ...DEFAULT_PREFERENCES } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    // Mirror defaults into AppSetting so Flutter reads work without migration.
    const ops = Object.entries(DEFAULT_PREFERENCES).map(([key, val]) => ({
      updateOne: {
        filter: { userId, settingKey: key },
        update: { $setOnInsert: { userId, settingKey: key, value: val, updatedAt: new Date() } },
        upsert: true,
      },
    }));
    await AppSetting.bulkWrite(ops);

    res.status(200).json({ success: true, message: 'Default preferences seeded', defaults: DEFAULT_PREFERENCES });
  } catch (error) {
    console.error('seed-defaults error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ── POST /api/settings/validate ──────────────────────────────────────────────
// SDS process 5.5 — Validate Config.
// Accepts { settingKey, value } and returns whether the value is acceptable
// before the client persists it.
router.post('/validate', (req, res) => {
  const { settingKey, value } = req.body;
  if (!settingKey) {
    return res.status(400).json({ success: false, message: 'settingKey is required' });
  }
  const error = validatePreference(settingKey, value);
  if (error) {
    return res.status(422).json({ success: false, valid: false, message: error });
  }
  res.status(200).json({ success: true, valid: true });
});

// ── POST /api/settings ────────────────────────────────────────────────────────
// Upsert a single setting; validates typed preference keys before saving.
router.post('/', async (req, res) => {
  try {
    const { userId, settingKey, value } = req.body;

    // Run validation for known preference keys.
    const error = validatePreference(settingKey, value);
    if (error) {
      return res.status(422).json({ success: false, message: error });
    }

    let setting = await AppSetting.findOne({ userId, settingKey });

    if (setting) {
      setting.value = value;
      setting.updatedAt = new Date();
    } else {
      setting = new AppSetting({ userId, settingKey, value, updatedAt: new Date() });
    }

    const saved = await setting.save();

    // Keep the typed UserPreferences document in sync for known fields.
    if (PREFERENCE_RULES[settingKey]) {
      const update = {};
      update[settingKey] = value;
      await UserPreferences.findOneAndUpdate(
        { userId },
        { $set: update },
        { upsert: false } // only update; seed-defaults must have run first
      );
    }

    res.status(201).json(saved);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// ── GET /api/settings/:userId/:settingKey ─────────────────────────────────────
router.get('/:userId/:settingKey', async (req, res) => {
  try {
    const setting = await AppSetting.findOne({
      userId: req.params.userId,
      settingKey: req.params.settingKey,
    });
    res.json(setting || { value: null });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// ── GET /api/settings/user/:userId ───────────────────────────────────────────
router.get('/user/:userId', async (req, res) => {
  try {
    const settings = await AppSetting.find({ userId: req.params.userId });
    res.json(settings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// ── GET /api/settings/preferences/:userId ────────────────────────────────────
// Returns the typed UserPreferences document (includes all typed fields).
router.get('/preferences/:userId', async (req, res) => {
  try {
    const prefs = await UserPreferences.findOne({ userId: req.params.userId });
    if (!prefs) {
      return res.status(404).json({ success: false, message: 'No preferences found. Call seed-defaults first.' });
    }
    res.json({ success: true, preferences: prefs });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;