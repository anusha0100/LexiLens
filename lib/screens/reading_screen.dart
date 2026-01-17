// lib/screens/reading_screen.dart (UPDATED FOR UPLOADED DOCUMENTS)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/filter_screen.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  bool _useOpenDyslexic = true;
  double _fontSize = 18.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final document = state.currentDocument;
        
        // Debug print
        print('📖 Reading Screen - Current Document: ${document?.name}');
        print('📝 Content available: ${document?.content.isNotEmpty ?? false}');
        print('📝 Content length: ${document?.content.length ?? 0}');
        
        if (document == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFFB789DA),
              title: const Text(
                'Reading',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: Text(
                'No document selected',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ),
          );
        }

        Color backgroundColor = _getBackgroundColor(state.selectedBackgroundColor);
        Color textColor = _getTextColor(state.selectedTextColor);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFFE8BFD5),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                context.read<AppBloc>().add(StopTextToSpeech());
                Navigator.pop(context);
              },
            ),
            title: Text(
              document.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _useOpenDyslexic ? Icons.font_download : Icons.font_download_outlined,
                  color: Colors.white,
                ),
                tooltip: _useOpenDyslexic ? 'Disable OpenDyslexic' : 'Enable OpenDyslexic',
                onPressed: () {
                  setState(() {
                    _useOpenDyslexic = !_useOpenDyslexic;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _useOpenDyslexic 
                            ? 'OpenDyslexic font enabled' 
                            : 'Default font enabled',
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFFB789DA),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => _showSettingsDialog(context, state),
              ),
            ],
          ),
          body: Column(
            children: [
              // Control Bar
              Container(
                color: const Color(0xFFE8BFD5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      icon: Icons.text_fields,
                      label: 'Font',
                      isActive: _useOpenDyslexic,
                      onTap: () {
                        setState(() {
                          _useOpenDyslexic = !_useOpenDyslexic;
                        });
                      },
                    ),
                    _ControlButton(
                      icon: Icons.highlight,
                      label: 'Highlight',
                      isActive: state.isHighlighted,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleHighlight());
                      },
                    ),
                  ],
                ),
              ),
              // Reading Content
              Expanded(
                child: Container(
                  color: backgroundColor,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: _buildText(context, state, document, textColor),
                  ),
                ),
              ),
              // Media Controls
              Container(
                color: const Color(0xFF1F1F39),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
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
                                fontFamily: 'OpenDyslexic',
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
                                fontFamily: 'OpenDyslexic',
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
                          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                          onPressed: () {
                            context.read<AppBloc>().add(StopTextToSpeech());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
                          onPressed: () {},
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
                              if (document.content.isNotEmpty) {
                                print('🔊 Starting TTS with ${document.content.length} characters');
                                context.read<AppBloc>().add(StartTextToSpeech(text: document.content));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No text available to read'),
                                    backgroundColor: Color(0xFFB789DA),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
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
                      icon: const Icon(Icons.home, color: Colors.white),
                      onPressed: () {
                        context.read<AppBloc>().add(StopTextToSpeech());
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_alt, color: Colors.white),
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
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () => _showSettingsDialog(context, state),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildText(BuildContext context, AppState state, Document document, Color textColor) {
    if (document.content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.text_snippet_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
      );
    }

    final words = document.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    if (state.readingState == ReadingState.idle) {
      return SelectableText(
        document.content,
        style: TextStyle(
          fontSize: _fontSize,
          height: 1.8,
          fontFamily: _useOpenDyslexic ? 'OpenDyslexic' : null,
          color: textColor,
          letterSpacing: _useOpenDyslexic ? 0.5 : 0,
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
              fontSize: _fontSize,
              fontFamily: _useOpenDyslexic ? 'OpenDyslexic' : null,
              height: 1.8,
              backgroundColor: isCurrentWord 
                  ? Colors.yellow.withOpacity(0.5) 
                  : (state.isHighlighted 
                      ? const Color(0xFFB7B9DA).withOpacity(0.3) 
                      : null),
              fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal,
              letterSpacing: _useOpenDyslexic ? 0.5 : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<AppBloc>(),
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Reading Settings',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'OpenDyslexic Font',
                        style: TextStyle(fontFamily: 'OpenDyslexic'),
                      ),
                      value: _useOpenDyslexic,
                      activeColor: const Color(0xFFB789DA),
                      onChanged: (value) {
                        setState(() {
                          _useOpenDyslexic = value;
                        });
                        this.setState(() {
                          _useOpenDyslexic = value;
                        });
                      },
                    ),
                    const Divider(),
                    Text(
                      'Font Size: ${_fontSize.toInt()}',
                      style: const TextStyle(fontFamily: 'OpenDyslexic'),
                    ),
                    Slider(
                      value: _fontSize,
                      min: 12.0,
                      max: 32.0,
                      divisions: 20,
                      activeColor: const Color(0xFFB789DA),
                      onChanged: (value) {
                        setState(() {
                          _fontSize = value;
                        });
                        this.setState(() {
                          _fontSize = value;
                        });
                      },
                    ),
                    const Divider(),
                    BlocBuilder<AppBloc, AppState>(
                      builder: (context, state) {
                        return Column(
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
                            const SizedBox(height: 8),
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
                          ],
                        );
                      },
                    ),
                  ],
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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