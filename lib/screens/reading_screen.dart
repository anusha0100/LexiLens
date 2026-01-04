// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/filter_screen.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8BFD5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back, 
            color: Colors.white,
          ),
          onPressed: () {
            context.read<AppBloc>().add(StopTextToSpeech());
            Navigator.pop(context);
          },
        ),
        title: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            return Text(
              state.currentDocument?.name ?? 'Reading',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'OpenDyslexic',
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search, 
              color: Colors.white,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          Color backgroundColor = _getBackgroundColor(state.selectedBackgroundColor);
          Color textColor = _getTextColor(state.selectedTextColor);
          
          return Column(
            children: [
              // Control Bar
              Container(
                color: const Color(0xFFE8BFD5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: state.isSoundEnabled ? Icons.volume_up : Icons.volume_off,
                      label: 'Sound',
                      isActive: state.isSoundEnabled,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleSound());
                      },
                    ),
                    _ControlButton(
                      icon: Icons.bookmark,
                      label: 'Bookmark',
                      isActive: state.isBookmarked,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleBookmark());
                      },
                    ),
                    _ControlButton(
                      icon: Icons.text_fields,
                      label: 'Font',
                      isActive: state.isFontEnabled,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleFont());
                      },
                    ),
                    _ControlButton(
                      icon: Icons.highlight,
                      label: 'Highlights',
                      isActive: state.isHighlighted,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleHighlight());
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: backgroundColor,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: _buildHighlightedText(context, state, textColor),
                  ),
                ),
              ),
              // Media Controls
              Container(
                color: const Color(0xFF1F1F39),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    // Progress indicator
                    if (state.readingState != ReadingState.idle)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text(
                              'Word: ${state.currentWordIndex + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              state.readingState == ReadingState.playing 
                                  ? 'Playing' 
                                  : 'Paused',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous, 
                            color: Colors.white, 
                            size: 32,
                          ),
                          onPressed: () {
                            context.read<AppBloc>().add(StopTextToSpeech());
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.replay_10, 
                            color: Colors.white, 
                            size: 32,
                          ),
                          onPressed: () {
                            // TODO: Implement skip back 10 seconds
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            state.readingState == ReadingState.playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48,
                          ),
                          onPressed: () {
                            if (!state.isSoundEnabled) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enable sound first'),
                                  backgroundColor: Color(0xFFB789DA),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            
                            if (state.readingState == ReadingState.playing) {
                              context.read<AppBloc>().add(PauseTextToSpeech());
                            } else if (state.readingState == ReadingState.paused) {
                              context.read<AppBloc>().add(ResumeTextToSpeech());
                            } else {
                              final text = state.currentDocument?.content;
                              if (text != null && text.isNotEmpty) {
                                context.read<AppBloc>().add(StartTextToSpeech(text: text));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No text available to read'),
                                    backgroundColor: Color(0xFFB789DA),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.forward_10, 
                            color: Colors.white, 
                            size: 32,
                          ),
                          onPressed: () {
                            // TODO: Implement skip forward 10 seconds
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next, 
                            color: Colors.white, 
                            size: 32,
                          ),
                          onPressed: () {
                            context.read<AppBloc>().add(StopTextToSpeech());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFFB789DA),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.home, 
                    color: Colors.white,
                  ),
                  onPressed: () {
                    context.read<AppBloc>().add(StopTextToSpeech());
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.camera_alt, 
                    color: Colors.white,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    Icons.description, 
                    color: Colors.white,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    Icons.filter_alt, 
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<AppBloc>(),
                          child: const FilterScreen(),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.settings, 
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _showSettingsDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(BuildContext context, AppState state, Color textColor) {
    final content = state.currentDocument?.content ?? 
        "I SWORE IT WASN'T STEALING—reading until we outgrew it. It wasn't like I got into that room because I trespassed or something.";
    final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (state.readingState == ReadingState.idle) {
      return Text(
        content,
        style: TextStyle(
          fontSize: 16,
          height: 1.8,
          fontFamily: 'OpenDyslexic',
          color: state.isHighlighted ? const Color(0xFFB7B9DA) : textColor,
          backgroundColor: state.isHighlighted 
              ? const Color(0xFFB7B9DA).withOpacity(0.3) 
              : null,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isCurrentWord = index == state.currentWordIndex;
          
          return TextSpan(
            text: '$word ',
            style: TextStyle(
              color: isCurrentWord ? Colors.red : textColor,
              fontSize: 16,
              fontFamily: 'OpenDyslexic',
              height: 1.8,
              backgroundColor: isCurrentWord 
                  ? Colors.yellow.withOpacity(0.5) 
                  : (state.isHighlighted 
                      ? const Color(0xFFB7B9DA).withOpacity(0.3) 
                      : null),
              fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<AppBloc>(),
        child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            return AlertDialog(
              title: const Text(
                'Audio Settings',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reading Speed: ${(state.readingSpeed * 2).toStringAsFixed(1)}x',
                    style: const TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  Slider(
                    value: state.readingSpeed,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      context.read<AppBloc>().add(AdjustSpeed(value));
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Volume: ${(state.volume * 100).toInt()}%',
                    style: const TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  Slider(
                    value: state.volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      context.read<AppBloc>().add(AdjustVolume(value));
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pitch: ${state.pitch.toStringAsFixed(1)}',
                    style: const TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  Slider(
                    value: state.pitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      context.read<AppBloc>().add(AdjustPitch(value));
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Color(0xFFB789DA),
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
    return index < colors.length ? colors[index] : const Color(0xFFF0F022);
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
    return index < colors.length ? colors[index] : const Color(0xFF1F1F39);
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12, 
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFB789DA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.white : const Color(0xFF1F1F39),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.white : const Color(0xFF1F1F39),
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
      ),
    );
  }
}