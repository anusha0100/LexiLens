// lib/screens/preferences_screen.dart
// ignore_for_file: deprecated_member_use

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
  final _authService   = AuthService();
  final _mongoService  = MongoDBService();

  bool   _autoSave         = true;
  bool   _highContrast     = false;
  bool   _wordHighlight    = true;
  bool   _lineSpacing      = false;
  bool   _showDefinitions  = false;
  String _defaultFont      = 'OpenDyslexic';
  double _defaultFontSize  = 18.0;

  bool _isLoading = true;
  bool _isSaving  = false;

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
        if (mounted) {
          setState(() {
            _autoSave        = settings['pref_auto_save']        ?? true;
            _highContrast    = settings['pref_high_contrast']    ?? false;
            _wordHighlight   = settings['pref_word_highlight']   ?? true;
            _lineSpacing     = settings['pref_line_spacing']     ?? false;
            _showDefinitions = settings['pref_show_definitions'] ?? false;
            _defaultFont     = settings['pref_default_font']     ?? 'OpenDyslexic';
            final raw = (settings['font_size'] ??
                    settings['pref_default_font_size'] ?? 18.0)
                .toDouble();
            _defaultFontSize = raw.clamp(12.0, 36.0);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      await _mongoService.updateSetting(userId, 'font_size',             _defaultFontSize);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preferences saved successfully!'),
          backgroundColor: Color(0xFFB789DA),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving preferences: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Use Theme.of(context) directly — no local Theme wrapper that was
    // overriding the global MaterialApp darkTheme and stripping the colour scheme.
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark      = theme.brightness == Brightness.dark;

    // Derive surface colours from the active theme.
    final bg     = theme.scaffoldBackgroundColor;
    final onBg   = colorScheme.onSurface;
    final tile   = isDark ? const Color(0xFF2D2545) : Colors.grey.shade50;
    final border = isDark ? const Color(0xFF3D3060) : Colors.grey.shade200;

    return BlocBuilder<AppBloc, AppState>(
      // Only rebuild when dark-mode or font-size changes.
      buildWhen: (p, n) => p.isDarkMode != n.isDarkMode || p.fontSize != n.fontSize,
      builder: (context, appState) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: const Color(0xFFB789DA),
            title: const Text('Preferences',
                style: TextStyle(fontFamily: 'OpenDyslexic', color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFB789DA)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Appearance ────────────────────────────────────────
                      _sectionTitle('Appearance', onBg),
                      _switchTile(
                        title:    'Dark Mode',
                        subtitle: 'Switch to a dark colour theme',
                        value:    appState.isDarkMode,
                        icon:     Icons.dark_mode,
                        tile:     tile,
                        border:   border,
                        onBg:     onBg,
                        onChanged: (_) =>
                            context.read<AppBloc>().add(ToggleDarkMode()),
                      ),
                      _switchTile(
                        title:    'High Contrast Mode',
                        subtitle: 'Increase contrast for better readability',
                        value:    _highContrast,
                        icon:     Icons.contrast,
                        tile:     tile,
                        border:   border,
                        onBg:     onBg,
                        onChanged: (v) => setState(() => _highContrast = v),
                      ),

                      const SizedBox(height: 24),
                      Divider(color: border),
                      const SizedBox(height: 24),

                      // ── Reading ───────────────────────────────────────────
                      _sectionTitle('Reading Preferences', onBg),
                      _switchTile(
                        title:    'Word Highlighting',
                        subtitle: 'Highlight current word during reading',
                        value:    _wordHighlight,
                        icon:     Icons.highlight,
                        tile:     tile,
                        border:   border,
                        onBg:     onBg,
                        onChanged: (v) => setState(() => _wordHighlight = v),
                      ),
                      _switchTile(
                        title:    'Increased Line Spacing',
                        subtitle: 'Add extra space between lines',
                        value:    _lineSpacing,
                        icon:     Icons.format_line_spacing,
                        tile:     tile,
                        border:   border,
                        onBg:     onBg,
                        onChanged: (v) => setState(() => _lineSpacing = v),
                      ),
                      _switchTile(
                        title:    'Show Word Definitions',
                        subtitle: 'Display definitions on long press',
                        value:    _showDefinitions,
                        icon:     Icons.menu_book,
                        tile:     tile,
                        border:   border,
                        onBg:     onBg,
                        onChanged: (v) => setState(() => _showDefinitions = v),
                      ),

                      const SizedBox(height: 24),
                      Divider(color: border),
                      const SizedBox(height: 24),

                      // ── Font ──────────────────────────────────────────────
                      _sectionTitle('Font Preferences', onBg),
                      _buildFontSelector(tile, border, onBg, context),
                      const SizedBox(height: 16),
                      _buildFontSizeSlider(appState, tile, border, onBg, bg, context),

                      const SizedBox(height: 24),
                      Divider(color: border),
                      const SizedBox(height: 24),

                      // ── General ───────────────────────────────────────────
                      _sectionTitle('General', onBg),
                      _switchTile(
                        title:    'Auto-Save Documents',
                        subtitle: 'Automatically save scanned documents',
                        value:    _autoSave,
                        icon:     Icons.save_alt,
                        tile:     tile,
                        border:   border,
                        onBg:     onBg,
                        onChanged: (v) => setState(() => _autoSave = v),
                      ),

                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _savePreferences,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:         const Color(0xFFB789DA),
                            foregroundColor:         Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Save Preferences',
                                  style: TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'OpenDyslexic')),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ── Reusable helpers ───────────────────────────────────────────────────────

  Widget _sectionTitle(String title, Color onBg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic', color: Color(0xFFB789DA))),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool   value,
    required IconData icon,
    required Color  tile,
    required Color  border,
    required Color  onBg,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFFB789DA)),
        title: Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                fontFamily: 'OpenDyslexic', color: onBg)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: onBg.withOpacity(0.6),
                fontFamily: 'OpenDyslexic')),
        value: value,
        activeColor: const Color(0xFFB789DA),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFontSelector(
      Color tile, Color border, Color onBg, BuildContext ctx) {
    const fonts = ['OpenDyslexic', 'Arial', 'Georgia', 'Verdana'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default Font',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'OpenDyslexic', color: onBg)),
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
                  if (font == 'OpenDyslexic') {
                    if (!ctx.read<AppBloc>().state.useOpenDyslexic) {
                      ctx.read<AppBloc>().add(ToggleOpenDyslexic());
                    }
                  } else {
                    if (ctx.read<AppBloc>().state.useOpenDyslexic) {
                      ctx.read<AppBloc>().add(ToggleOpenDyslexic());
                    }
                    ctx.read<AppBloc>().add(ChangeFontFamily(font));
                  }
                },
                selectedColor: const Color(0xFFB789DA),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : onBg,
                  fontFamily: 'OpenDyslexic',
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSlider(AppState appState, Color tile, Color border,
      Color onBg, Color bg, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Default Font Size',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      fontFamily: 'OpenDyslexic', color: onBg)),
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
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Text('Preview text',
                style: TextStyle(
                  fontSize:   _defaultFontSize,
                  fontFamily: _defaultFont == 'OpenDyslexic' ? 'OpenDyslexic' : null,
                  color:      onBg,
                )),
          ),
          Slider(
            value:     _defaultFontSize,
            min:       12, max: 36, divisions: 24,
            activeColor: const Color(0xFFB789DA),
            label:     '${_defaultFontSize.toInt()}pt',
            onChanged: (v) {
              setState(() => _defaultFontSize = v);
              ctx.read<AppBloc>().add(AdjustFontSize(v));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12pt', style: TextStyle(fontSize: 10,
                  color: onBg.withOpacity(0.5), fontFamily: 'OpenDyslexic')),
              Text('36pt', style: TextStyle(fontSize: 10,
                  color: onBg.withOpacity(0.5), fontFamily: 'OpenDyslexic')),
            ],
          ),
        ],
      ),
    );
  }
}