// lib/screens/preferences_screen.dart
// FR-020: Font size range enforced to 12pt–36pt (was capped at 24pt).
// FR-021: Dark mode toggle added as a separate, user-controllable preference.

import 'package:flutter/material.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _authService = AuthService();
  final _mongoService = MongoDBService();

  // ── Reading toggles ────────────────────────────────────────────────────────
  bool _autoSave = true;
  bool _highContrast = false;
  bool _darkMode = false;          // FR-021: separate dark mode preference
  bool _wordHighlight = true;
  bool _lineSpacing = false;
  bool _showDefinitions = false;

  // ── Font preferences ───────────────────────────────────────────────────────
  String _defaultFont = 'OpenDyslexic';
  // FR-020: must be clamped to 12–36 pt; was 12–24 previously.
  double _defaultFontSize = 16.0;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.getUserId();
      if (userId != null) {
        final settings = await _mongoService.getAllSettings(userId);
        setState(() {
          _autoSave       = settings['pref_auto_save']       ?? true;
          _highContrast   = settings['pref_high_contrast']   ?? false;
          _darkMode       = settings['pref_dark_mode']       ?? false;  // FR-021
          _wordHighlight  = settings['pref_word_highlight']  ?? true;
          _lineSpacing    = settings['pref_line_spacing']    ?? false;
          _showDefinitions= settings['pref_show_definitions']?? false;
          _defaultFont    = settings['pref_default_font']    ?? 'OpenDyslexic';
          // FR-020: clamp persisted value into the correct 12–36 range
          final raw = (settings['pref_default_font_size'] ?? 16.0).toDouble();
          _defaultFontSize = raw.clamp(12.0, 36.0);
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      final userId = _authService.getUserId();
      if (userId == null) throw Exception('User not logged in');

      await _mongoService.updateSetting(userId, 'pref_auto_save',        _autoSave);
      await _mongoService.updateSetting(userId, 'pref_high_contrast',    _highContrast);
      await _mongoService.updateSetting(userId, 'pref_dark_mode',        _darkMode);      // FR-021
      await _mongoService.updateSetting(userId, 'pref_word_highlight',   _wordHighlight);
      await _mongoService.updateSetting(userId, 'pref_line_spacing',     _lineSpacing);
      await _mongoService.updateSetting(userId, 'pref_show_definitions', _showDefinitions);
      await _mongoService.updateSetting(userId, 'pref_default_font',     _defaultFont);
      await _mongoService.updateSetting(userId, 'pref_default_font_size',_defaultFontSize);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully!'),
            backgroundColor: Color(0xFFB789DA),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Effective background / text colours driven by dark-mode pref ──────────
  Color get _bg    => _darkMode ? const Color(0xFF1F1A2E) : Colors.white;
  Color get _onBg  => _darkMode ? const Color(0xFFEDE0F7) : Colors.black87;
  Color get _tile  => _darkMode ? const Color(0xFF2D2545) : Colors.grey.shade50;
  Color get _border=> _darkMode ? const Color(0xFF3D3060) : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Apply dark / light theming to this screen based on the preference.
      data: _darkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFFB789DA),
          title: const Text(
            'Preferences',
            style: TextStyle(fontFamily: 'OpenDyslexic', color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFB789DA)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Appearance ─────────────────────────────────────────
                    _buildSectionTitle('Appearance'),
                    // FR-021: Dark mode – separate, user-controllable toggle
                    _buildSwitchTile(
                      'Dark Mode',
                      'Switch to a dark colour theme',
                      _darkMode,
                      Icons.dark_mode,
                      (v) => setState(() => _darkMode = v),
                    ),
                    _buildSwitchTile(
                      'High Contrast Mode',
                      'Increase contrast for better readability',
                      _highContrast,
                      Icons.contrast,
                      (v) => setState(() => _highContrast = v),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ── Reading ────────────────────────────────────────────
                    _buildSectionTitle('Reading Preferences'),
                    _buildSwitchTile(
                      'Word Highlighting',
                      'Highlight current word during reading',
                      _wordHighlight,
                      Icons.highlight,
                      (v) => setState(() => _wordHighlight = v),
                    ),
                    _buildSwitchTile(
                      'Increased Line Spacing',
                      'Add extra space between lines',
                      _lineSpacing,
                      Icons.format_line_spacing,
                      (v) => setState(() => _lineSpacing = v),
                    ),
                    _buildSwitchTile(
                      'Show Word Definitions',
                      'Display definitions on long press',
                      _showDefinitions,
                      Icons.menu_book,
                      (v) => setState(() => _showDefinitions = v),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ── Font ───────────────────────────────────────────────
                    _buildSectionTitle('Font Preferences'),
                    _buildFontSelector(),
                    const SizedBox(height: 16),
                    _buildFontSizeSlider(),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ── General ────────────────────────────────────────────
                    _buildSectionTitle('General'),
                    _buildSwitchTile(
                      'Auto-Save Documents',
                      'Automatically save scanned documents',
                      _autoSave,
                      Icons.save_alt,
                      (v) => setState(() => _autoSave = v),
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _savePreferences,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB789DA),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Save Preferences',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'OpenDyslexic',
          color: Color(0xFFB789DA),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFFB789DA)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenDyslexic',
            color: _onBg,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: _onBg.withOpacity(0.6),
            fontFamily: 'OpenDyslexic',
          ),
        ),
        value: value,
        activeColor: const Color(0xFFB789DA),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFontSelector() {
    const fonts = ['OpenDyslexic', 'Arial', 'Times New Roman', 'Verdana'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default Font',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'OpenDyslexic',
              color: _onBg,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fonts.map((font) {
              final isSelected = _defaultFont == font;
              return ChoiceChip(
                label: Text(font),
                selected: isSelected,
                onSelected: (_) => setState(() => _defaultFont = font),
                selectedColor: const Color(0xFFB789DA),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : _onBg,
                  fontFamily: 'OpenDyslexic',
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    // FR-020: range is 12pt–36pt as required by the SRS.
    const double kMin = 12.0;
    const double kMax = 36.0;
    const int kDivisions = 24; // 1pt steps

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Default Font Size',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'OpenDyslexic',
                  color: _onBg,
                ),
              ),
              Text(
                '${_defaultFontSize.toInt()}pt',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB789DA),
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
          // Live preview of the selected size
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(
              'Preview text',
              style: TextStyle(
                fontSize: _defaultFontSize,
                fontFamily: _defaultFont == 'OpenDyslexic' ? 'OpenDyslexic' : null,
                color: _onBg,
              ),
            ),
          ),
          Slider(
            value: _defaultFontSize,
            min: kMin,
            max: kMax,
            divisions: kDivisions,
            activeColor: const Color(0xFFB789DA),
            label: '${_defaultFontSize.toInt()}pt',
            onChanged: (v) => setState(() => _defaultFontSize = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12pt',
                  style: TextStyle(
                      fontSize: 10,
                      color: _onBg.withOpacity(0.5),
                      fontFamily: 'OpenDyslexic')),
              Text('36pt',
                  style: TextStyle(
                      fontSize: 10,
                      color: _onBg.withOpacity(0.5),
                      fontFamily: 'OpenDyslexic')),
            ],
          ),
        ],
      ),
    );
  }
}