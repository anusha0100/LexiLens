// lib/screens/preferences_screen.dart
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
  
  bool _autoSave = true;
  bool _highContrast = false;
  bool _wordHighlight = true;
  bool _lineSpacing = false;
  bool _showDefinitions = false;
  
  String _defaultFont = 'OpenDyslexic';
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
          _autoSave = settings['pref_auto_save'] ?? true;
          _highContrast = settings['pref_high_contrast'] ?? false;
          _wordHighlight = settings['pref_word_highlight'] ?? true;
          _lineSpacing = settings['pref_line_spacing'] ?? false;
          _showDefinitions = settings['pref_show_definitions'] ?? false;
          _defaultFont = settings['pref_default_font'] ?? 'OpenDyslexic';
          _defaultFontSize = (settings['pref_default_font_size'] ?? 16.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);

    try {
      final userId = _authService.getUserId();
      if (userId == null) throw Exception('User not logged in');

      // Save all preferences
      await _mongoService.updateSetting(userId, 'pref_auto_save', _autoSave);
      await _mongoService.updateSetting(userId, 'pref_high_contrast', _highContrast);
      await _mongoService.updateSetting(userId, 'pref_word_highlight', _wordHighlight);
      await _mongoService.updateSetting(userId, 'pref_line_spacing', _lineSpacing);
      await _mongoService.updateSetting(userId, 'pref_show_definitions', _showDefinitions);
      await _mongoService.updateSetting(userId, 'pref_default_font', _defaultFont);
      await _mongoService.updateSetting(userId, 'pref_default_font_size', _defaultFontSize);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Preferences',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFB789DA),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reading Preferences
                  _buildSectionTitle('Reading Preferences'),
                  _buildSwitchTile(
                    'Word Highlighting',
                    'Highlight current word during reading',
                    _wordHighlight,
                    (value) => setState(() => _wordHighlight = value),
                  ),
                  _buildSwitchTile(
                    'High Contrast Mode',
                    'Increase contrast for better readability',
                    _highContrast,
                    (value) => setState(() => _highContrast = value),
                  ),
                  _buildSwitchTile(
                    'Increased Line Spacing',
                    'Add extra space between lines',
                    _lineSpacing,
                    (value) => setState(() => _lineSpacing = value),
                  ),
                  _buildSwitchTile(
                    'Show Word Definitions',
                    'Display definitions on long press',
                    _showDefinitions,
                    (value) => setState(() => _showDefinitions = value),
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Font Preferences
                  _buildSectionTitle('Font Preferences'),
                  _buildFontSelector(),
                  const SizedBox(height: 16),
                  _buildFontSizeSlider(),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // General Preferences
                  _buildSectionTitle('General'),
                  _buildSwitchTile(
                    'Auto-Save Documents',
                    'Automatically save scanned documents',
                    _autoSave,
                    (value) => setState(() => _autoSave = value),
                  ),

                  const SizedBox(height: 40),

                  // Save Button
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
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
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
                ],
              ),
            ),
    );
  }

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
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
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
    final fonts = ['OpenDyslexic', 'Arial', 'Times New Roman', 'Verdana'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Default Font',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'OpenDyslexic',
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
                onSelected: (selected) {
                  setState(() => _defaultFont = font);
                },
                selectedColor: const Color(0xFFB789DA),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Default Font Size',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              Text(
                '${_defaultFontSize.toInt()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB789DA),
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
          Slider(
            value: _defaultFontSize,
            min: 12.0,
            max: 24.0,
            divisions: 12,
            activeColor: const Color(0xFFB789DA),
            onChanged: (value) {
              setState(() => _defaultFontSize = value);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              Text(
                '24',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}