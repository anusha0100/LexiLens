// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';

class FilterScreen extends StatelessWidget {
  const FilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close, 
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Filter',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'OpenDyslexic',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Background Color Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.palette, 
                                  color: Color(0xFFB789DA),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Background Color',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: List.generate(
                                7,
                                (index) => _ColorCircle(
                                  color: _getBackgroundColor(index),
                                  colorName: _getBackgroundColorName(index),
                                  isSelected: state.selectedBackgroundColor == index,
                                  onTap: () {
                                    context.read<AppBloc>().add(ChangeBackgroundColor(index));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Text Color Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.text_fields, 
                                  color: Color(0xFFB789DA),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Text Color',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: List.generate(
                                7,
                                (index) => _ColorCircle(
                                  color: _getTextColor(index),
                                  colorName: _getTextColorName(index),
                                  isSelected: state.selectedTextColor == index,
                                  onTap: () {
                                    context.read<AppBloc>().add(ChangeTextColor(index));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Color Coded Parts of Speech
                      const Text(
                        'Color Coded Parts of Speech',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _PartOfSpeechToggle(
                              label: 'Noun',
                              color: const Color(0xFFB789DA),
                              isEnabled: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PartOfSpeechToggle(
                              label: 'Adjectives',
                              color: const Color(0xFFE8BFD5),
                              isEnabled: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PartOfSpeechToggle(
                              label: 'Verb',
                              color: Colors.green[400]!,
                              isEnabled: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PartOfSpeechToggle(
                              label: 'Adverbs',
                              color: Colors.orange[400]!,
                              isEnabled: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PartOfSpeechToggle(
                              label: 'Pronoun',
                              color: Colors.blue[400]!,
                              isEnabled: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PartOfSpeechToggle(
                              label: 'Articles',
                              color: const Color(0xFFFDD835),
                              isEnabled: false,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Save Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AppBloc>().add(SaveFilterSettings());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB789DA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'SAVE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getBackgroundColor(int index) {
    final colors = [
      const Color(0xFFF0F022), 
      const Color(0xFF1F1F39),  
      const Color(0xFFB789DA),  
      const Color(0xFFB685CA),  
      Colors.white,
      const Color(0xFFFFF8E1),
      const Color(0xFFE8E8E8),
    ];
    return index < colors.length ? colors[index] : Colors.grey;
  }

  String _getBackgroundColorName(int index) {
    final names = [
      'F0F022',
      '1F1F39',
      'B789DA',
      'B685CA',
      'FFFFFF',
      'FFF8E1',
      'E8E8E8',
    ];
    return index < names.length ? names[index] : '';
  }

  Color _getTextColor(int index) {
    final colors = [
      const Color(0xFF1F1F39),  
      const Color(0xFF000000),  
      const Color(0xFF858597),  
      const Color(0xFFB789DA),  
      const Color(0xFFB7B9DA),  
      Colors.white,             
      const Color(0xFF686897),  
    ];
    return index < colors.length ? colors[index] : Colors.grey;
  }

  String _getTextColorName(int index) {
    final names = [
      '1F1F39',
      '000000',
      '858597',
      'B789DA',
      'B7B9DA',
      'FFFFFF',
      '686897',
    ];
    return index < names.length ? names[index] : '';
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final String colorName;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.colorName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFB789DA) : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFFB789DA).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color == Colors.white ? Colors.black : Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            '#$colorName',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }
}

class _PartOfSpeechToggle extends StatefulWidget {
  final String label;
  final Color color;
  final bool isEnabled;

  const _PartOfSpeechToggle({
    required this.label,
    required this.color,
    required this.isEnabled,
  });

  @override
  State<_PartOfSpeechToggle> createState() => _PartOfSpeechToggleState();
}

class _PartOfSpeechToggleState extends State<_PartOfSpeechToggle> {
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12, 
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isEnabled ? widget.color : Colors.grey[300]!,
          width: _isEnabled ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: _isEnabled ? FontWeight.bold : FontWeight.w600,
              fontFamily: 'OpenDyslexic',
              color: _isEnabled ? widget.color : Colors.grey[600],
            ),
          ),
          Switch(
            value: _isEnabled,
            onChanged: (value) {
              setState(() {
                _isEnabled = value;
              });
            },
            activeColor: widget.color,
            activeTrackColor: widget.color.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}