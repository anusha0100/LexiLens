// ignore_for_file: deprecated_member_use                                                                                                                                                                                                                                                                                                                                                                                       
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/screens/filter_screen.dart';
import 'package:lexilens/widgets/reading_ruler.dart';
import 'package:lexilens/services/text_selection_service.dart';
import 'package:lexilens/services/syllable_service.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _textSelectionService = TextSelectionService();
  final _syllableService = SyllableService();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final document = state.currentDocument;
        print('Reading Screen - Current Document: ${document?.name}');
        print('Content available: ${document?.content.isNotEmpty ?? false}');
        print('Content length: ${document?.content.length ?? 0}');

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

        Color backgroundColor =
            _getBackgroundColor(state.selectedBackgroundColor);
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
                  state.useOpenDyslexic
                      ? Icons.font_download
                      : Icons.font_download_outlined,
                  color: Colors.white,
                ),
                tooltip: state.useOpenDyslexic
                    ? 'Disable OpenDyslexic'
                    : 'Enable OpenDyslexic',
                onPressed: () {
                  context.read<AppBloc>().add(ToggleOpenDyslexic());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.useOpenDyslexic
                            ? 'Default font enabled'
                            : 'OpenDyslexic font enabled',
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
              // Control Panel
              Container(
                color: const Color(0xFFE8BFD5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: state.isSoundEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      label: 'Sound',
                      isActive: state.isSoundEnabled,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleSound());
                      },
                    ),
                    _ControlButton(
                      icon: Icons.straighten,
                      label: 'Ruler',
                      isActive: state.isRulerEnabled,
                      onTap: () {
                        context.read<AppBloc>().add(ToggleRuler());
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
              // Reading Area
              Expanded(
                child: Stack(
                  children: [
                    InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.0,
                      scaleEnabled: true,
                      panEnabled: true,
                      onInteractionUpdate: (details) {
                        if (details.scale != state.zoomLevel) {
                          context
                              .read<AppBloc>()
                              .add(AdjustZoom(details.scale));
                        }
                      },
                      child: Container(
                        color: backgroundColor,
                        padding: const EdgeInsets.all(24),
                        width: MediaQuery.of(context).size.width,
                        child: SingleChildScrollView(
                          child:
                              _buildText(context, state, document, textColor),
                        ),
                      ),
                    ),
                    // Ruler overlay
                    if (state.isRulerEnabled)
                      ReadingRuler(
                        screenSize: MediaQuery.of(context).size,
                        initialPosition: state.rulerPosition,
                        onPositionChanged: (position) {
                          context
                              .read<AppBloc>()
                              .add(UpdateRulerPosition(position));
                        },
                      ),
                    // Zoom indicator
                    if (state.zoomLevel > 1.0)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(state.zoomLevel * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  context.read<AppBloc>().add(ResetZoom());
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Playback Controls
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
                          icon: const Icon(Icons.skip_previous,
                              color: Colors.white, size: 32),
                          onPressed: () {
                            context.read<AppBloc>().add(StopTextToSpeech());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay_10,
                              color: Colors.white, size: 32),
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
                            } else if (state.readingState ==
                                ReadingState.paused) {
                              context.read<AppBloc>().add(ResumeTextToSpeech());
                            } else {
                              if (document.content.isNotEmpty) {
                                print(
                                    'Starting TTS with ${document.content.length} characters');
                                context.read<AppBloc>().add(
                                    StartTextToSpeech(text: document.content));
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
                          icon: const Icon(Icons.forward_10,
                              color: Colors.white, size: 32),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next,
                              color: Colors.white, size: 32),
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

  Widget _buildText(BuildContext context, AppState state, Document document,
      Color textColor) {
    if (document.content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.text_snippet_outlined,
                size: 64, color: Colors.grey[400]),
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

    final words = _textSelectionService.extractWords(document.content);
    String? fontFamily;
    if (state.useOpenDyslexic) {
      if (_isLatinText(document.content)) {
        fontFamily = 'OpenDyslexic';
      } else {
        fontFamily = null;
      }
    }

    if (state.readingState == ReadingState.idle) {
      return SelectableText(
        document.content,
        style: TextStyle(
          fontSize: state.fontSize,
          height: state.lineSpacing,
          fontFamily: fontFamily,
          color: textColor,
          letterSpacing: fontFamily == 'OpenDyslexic' ? state.letterSpacing : 0,
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
              fontSize: state.fontSize,
              fontFamily: fontFamily,
              height: state.lineSpacing,
              backgroundColor: isCurrentWord
                  ? Colors.yellow.withOpacity(0.5)
                  : (state.isHighlighted
                      ? const Color(0xFFB7B9DA).withOpacity(0.2)
                      : null),
              fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal,
              letterSpacing:
                  fontFamily == 'OpenDyslexic' ? state.letterSpacing : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isLatinText(String text) {
    final latinPattern = RegExp(r'^[a-zA-Z0-9\s\p{P}]+$', unicode: true);
    final sample = text.length > 100 ? text.substring(0, 100) : text;
    return latinPattern.hasMatch(sample);
  }

  String _findWordAtPosition(
      BuildContext context, Offset position, List<String> words) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return '';

    
    final relativeY = position.dy;
    final fontSize = context.read<AppBloc>().state.fontSize;
    final lineSpacing = context.read<AppBloc>().state.lineSpacing;
    final lineHeight = fontSize * lineSpacing;

    final lineIndex = (relativeY / lineHeight).floor();

    
    final screenWidth = MediaQuery.of(context).size.width - 48; 
    final avgCharWidth = fontSize * 0.6;
    final wordsPerLine =
        (screenWidth / (avgCharWidth * 7)).floor();                                                                                                                                                                                                                                                                                                                               

    final wordIndex = (lineIndex * wordsPerLine).clamp(0, words.length - 1);

    if (wordIndex < words.length) {
      return _textSelectionService.cleanWord(words[wordIndex]);
    }

    return '';
  }

  void _showSyllableDialog(BuildContext context, String word) {
    final syllables = _syllableService.breakIntoSyllables(word);
    final formatted = _syllableService.formatSyllables(syllables);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color(0xFFB789DA),                 
        title: Text(
          word,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatted,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'OpenDyslexic',
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${syllables.length} syllable${syllables.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTextOptions(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => BlocProvider.value(
        value: context.read<AppBloc>(),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Text Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading:
                      const Icon(Icons.font_download, color: Color(0xFFB789DA)),
                  title: const Text('Font Settings',
                      style: TextStyle(fontFamily: 'OpenDyslexic')),
                  onTap: () {
                    Navigator.pop(context);
                    _showSettingsDialog(context, state);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.straighten, color: Color(0xFFB789DA)),
                  title: const Text('Toggle Ruler',
                      style: TextStyle(fontFamily: 'OpenDyslexic')),
                  trailing: Switch(
                    value: state.isRulerEnabled,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      context.read<AppBloc>().add(ToggleRuler());
                      Navigator.pop(context);
                    },
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.highlight, color: Color(0xFFB789DA)),
                  title: const Text('Toggle Highlight',
                      style: TextStyle(fontFamily: 'OpenDyslexic')),
                  trailing: Switch(
                    value: state.isHighlighted,
                    activeColor: const Color(0xFFB789DA),
                    onChanged: (value) {
                      context.read<AppBloc>().add(ToggleHighlight());
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
                child: BlocBuilder<AppBloc, AppState>(
                  builder: (context, state) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Font Family Selection
                        const Text(
                          'Font Family',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            'OpenDyslexic',
                            'Arial',
                            'Times New Roman',
                            'Georgia',
                            'Verdana',
                          ].map((font) {
                            final isSelected = state.fontFamily == font ||
                                (font == 'OpenDyslexic' &&
                                    state.useOpenDyslexic);
                            return ChoiceChip(
                              label: Text(font),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (font == 'OpenDyslexic') {
                                  if (!state.useOpenDyslexic) {
                                    context
                                        .read<AppBloc>()
                                        .add(ToggleOpenDyslexic());
                                  }
                                } else {
                                  if (state.useOpenDyslexic) {
                                    context
                                        .read<AppBloc>()
                                        .add(ToggleOpenDyslexic());
                                  }
                                  context
                                      .read<AppBloc>()
                                      .add(ChangeFontFamily(font));
                                }
                              },
                              selectedColor: const Color(0xFFB789DA),
                              labelStyle: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontFamily: 'OpenDyslexic',
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),

                        // Font Size
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Font Size',
                              style: TextStyle(fontFamily: 'OpenDyslexic'),
                            ),
                            Text(
                              '${state.fontSize.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: state.fontSize,
                          min: 12.0,
                          max: 32.0,
                          divisions: 20,
                          activeColor: const Color(0xFFB789DA),
                          onChanged: (value) {
                            context.read<AppBloc>().add(AdjustFontSize(value));
                          },
                        ),

                        // Line Spacing
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Line Spacing',
                              style: TextStyle(fontFamily: 'OpenDyslexic'),
                            ),
                            Text(
                              '${state.lineSpacing.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: state.lineSpacing,
                          min: 1.0,
                          max: 3.0,
                          divisions: 20,
                          activeColor: const Color(0xFFB789DA),
                          onChanged: (value) {
                            context
                                .read<AppBloc>()
                                .add(AdjustLineSpacing(value));
                          },
                        ),

                        if (state.useOpenDyslexic) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Letter Spacing',
                                style: TextStyle(fontFamily: 'OpenDyslexic'),
                              ),
                              Text(
                                state.letterSpacing.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: state.letterSpacing,
                            min: 0.0,
                            max: 2.0,
                            divisions: 20,
                            activeColor: const Color(0xFFB789DA),
                            onChanged: (value) {
                              context
                                  .read<AppBloc>()
                                  .add(AdjustLetterSpacing(value));
                            },
                          ),
                        ],

                        const Divider(),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Overlay Opacity',
                              style: TextStyle(fontFamily: 'OpenDyslexic'),
                            ),
                            Text(
                              '${(state.overlayOpacity * 100).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: state.overlayOpacity,
                          min: 0.5,
                          max: 1.0,
                          divisions: 10,
                          activeColor: const Color(0xFFB789DA),
                          onChanged: (value) {
                            context
                                .read<AppBloc>()
                                .add(AdjustOverlayOpacity(value));
                          },
                        ),

                        const Divider(),
                        const SizedBox(height: 8),

                        // Audio Controls
                        const Text(
                          'Audio Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reading Speed',
                              style: TextStyle(fontFamily: 'OpenDyslexic'),
                            ),
                            Text(
                              '${(state.readingSpeed * 2).toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Volume',
                              style: TextStyle(fontFamily: 'OpenDyslexic'),
                            ),
                            Text(
                              '${(state.volume * 100).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
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

                        // Voice selection (if voices are loaded)
                        if (state.availableVoices.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Voice',
                            style: TextStyle(fontFamily: 'OpenDyslexic'),
                          ),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            value: state.selectedVoice,
                            hint: const Text('Default'),
                            items: state.availableVoices
                                .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                context.read<AppBloc>().add(SelectVoice(val));
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        const Divider(),
                        const SizedBox(height: 8),

                        // Zoom Control
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Zoom Level',
                              style: TextStyle(fontFamily: 'OpenDyslexic'),
                            ),
                            Text(
                              '${(state.zoomLevel * 100).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                final newZoom =
                                    (state.zoomLevel - 0.1).clamp(1.0, 3.0);
                                context
                                    .read<AppBloc>()
                                    .add(AdjustZoom(newZoom));
                              },
                            ),
                            Expanded(
                              child: Slider(
                                value: state.zoomLevel,
                                min: 1.0,
                                max: 3.0,
                                divisions: 20,
                                activeColor: const Color(0xFFB789DA),
                                onChanged: (value) {
                                  context
                                      .read<AppBloc>()
                                      .add(AdjustZoom(value));
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                final newZoom =
                                    (state.zoomLevel + 0.1).clamp(1.0, 3.0);
                                context
                                    .read<AppBloc>()
                                    .add(AdjustZoom(newZoom));
                              },
                            ),
                          ],
                        ),
                        if (state.zoomLevel > 1.0)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                context.read<AppBloc>().add(ResetZoom());
                              },
                              child: const Text(
                                'Reset Zoom',
                                style: TextStyle(
                                  color: Color(0xFFB789DA),
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
          mainAxisSize: MainAxisSize.min,
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
