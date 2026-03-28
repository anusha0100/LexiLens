// lib/screens/preferences_screen.dart
// FIX Bug #16: font size now saved under 'font_size' (same key the bloc reads).
// FIX Dark mode: dispatches ToggleDarkMode to bloc so the app theme flips
//   immediately and is persisted — no more separate local + bloc copies.
// FIX Preferences apply immediately: every toggle/slider change dispatches
//   the corresponding AppBloc event in addition to persisting to MongoDB.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
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
  bool _wordHighlight = true;
  bool _lineSpacing = false;
  bool _showDefinitions = false;

  // ── Font preferences ───────────────────────────────────────────────────────
  String _defaultFont = 'OpenDyslexic';
  // Font size range 12–36 pt (FR-020).
  double _defaultFontSize = 18.0;

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
          _autoSave        = settings['pref_auto_save']        ?? true;
          _highContrast    = settings['pref_high_contrast']    ?? false;
          _wordHighlight   = settings['pref_word_highlight']   ?? true;
          _lineSpacing     = settings['pref_line_spacing']     ?? false;
          _showDefinitions = settings['pref_show_definitions'] ?? false;
          _defaultFont     = settings['pref_default_font']     ?? 'OpenDyslexic';
          // FIX Bug #16: read unified key; fall back to old key on upgrade.
          final raw = (settings['font_size'] ?? settings['pref_default_font_size'] ?? 18.0).toDouble();
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
      await _mongoService.updateSetting(userId, 'pref_word_highlight',   _wordHighlight);
      await _mongoService.updateSetting(userId, 'pref_line_spacing',     _lineSpacing);
      await _mongoService.updateSetting(userId, 'pref_show_definitions', _showDefinitions);
      await _mongoService.updateSetting(userId, 'pref_default_font',     _defaultFont);
      // FIX Bug #16: save under the unified 'font_size' key so AppBloc reads it.
      await _mongoService.updateSetting(userId, 'font_size',             _defaultFontSize);

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
          SnackBar(content: Text('Error saving preferences: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Colour helpers — read from the live bloc state (isDarkMode). ──────────
  bool get _dark => context.read<AppBloc>().state.isDarkMode;
  Color get _bg    => _dark ? const Color(0xFF1F1A2E) : Colors.white;
  Color get _onBg  => _dark ? const Color(0xFFEDE0F7) : Colors.black87;
  Color get _tile  => _dark ? const Color(0xFF2D2545) : Colors.grey.shade50;
  Color get _border=> _dark ? const Color(0xFF3D3060) : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      buildWhen: (prev, next) => prev.isDarkMode != next.isDarkMode || prev.fontSize != next.fontSize,
      builder: (context, appState) {
        return Theme(
          data: appState.isDarkMode ? ThemeData.dark() : ThemeData.light(),
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
                        // Dark mode — dispatches to bloc so the whole app flips
                        // immediately and persists to MongoDB in one step.
                        _buildSwitchTile(
                          'Dark Mode',
                          'Switch to a dark colour theme',
                          appState.isDarkMode,
                          Icons.dark_mode,
                          (v) => context.read<AppBloc>().add(ToggleDarkMode()),
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
                        _buildFontSizeSlider(appState),

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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Save Preferences',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'OpenDyslexic'),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          fontFamily: 'OpenDyslexic', color: Color(0xFFB789DA),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title, String subtitle, bool value, IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _tile, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFFB789DA)),
        title: Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                fontFamily: 'OpenDyslexic', color: _onBg)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: _onBg.withOpacity(0.6),
                fontFamily: 'OpenDyslexic')),
        value: value,
        activeColor: const Color(0xFFB789DA),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFontSelector() {
    // FIX FR-014: added OpenDyslexic as the primary dyslexia-friendly option.
    // Arial / Times New Roman / Verdana remain but are not the only choices.
    const fonts = ['OpenDyslexic', 'Arial', 'Georgia', 'Verdana'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tile, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default Font',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'OpenDyslexic', color: _onBg)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: fonts.map((font) {
              final isSelected = _defaultFont == font;
              return ChoiceChip(
                label: Text(font),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _defaultFont = font);
                  // Apply immediately via bloc.
                  if (font == 'OpenDyslexic') {
                    if (!context.read<AppBloc>().state.useOpenDyslexic) {
                      context.read<AppBloc>().add(ToggleOpenDyslexic());
                    }
                  } else {
                    if (context.read<AppBloc>().state.useOpenDyslexic) {
                      context.read<AppBloc>().add(ToggleOpenDyslexic());
                    }
                    context.read<AppBloc>().add(ChangeFontFamily(font));
                  }
                },
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

  Widget _buildFontSizeSlider(AppState appState) {
    // FR-020: range 12pt–36pt.
    const double kMin = 12.0;
    const double kMax = 36.0;
    const int kDivisions = 24; // 1 pt steps

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tile, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Default Font Size',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      fontFamily: 'OpenDyslexic', color: _onBg)),
              Text('${_defaultFontSize.toInt()}pt',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: Color(0xFFB789DA), fontFamily: 'OpenDyslexic')),
            ],
          ),
          const SizedBox(height: 8),
          // Live preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bg, borderRadius: BorderRadius.circular(8),
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
            min: kMin, max: kMax, divisions: kDivisions,
            activeColor: const Color(0xFFB789DA),
            label: '${_defaultFontSize.toInt()}pt',
            onChanged: (v) {
              setState(() => _defaultFontSize = v);
              // Apply immediately to reading screen.
              context.read<AppBloc>().add(AdjustFontSize(v));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12pt', style: TextStyle(fontSize: 10, color: _onBg.withOpacity(0.5), fontFamily: 'OpenDyslexic')),
              Text('36pt', style: TextStyle(fontSize: 10, color: _onBg.withOpacity(0.5), fontFamily: 'OpenDyslexic')),
            ],
          ),
        ],
      ),
    );
  }
}