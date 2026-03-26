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

// ── Colour palette (never changes between states) ──────────────────────────
const _kPrimary   = Color(0xFF7B4FA6);   // deep purple
const _kAccent    = Color(0xFFB789DA);   // soft purple
const _kSurface   = Color(0xFF1F1A2E);   // dark navy
const _kOnSurface = Color(0xFFEDE0F7);   // lavender-white
const _kBar       = Color(0xFF2D2545);   // darker bar background

// ── Part-of-speech colour coding ─────────────────────────────────────────────
const _kPosColors = <String, Color>{
  'noun':        Color(0xFF64B5F6), // sky-blue
  'verb':        Color(0xFF81C784), // green
  'adjective':   Color(0xFFFFD54F), // amber
  'adverb':      Color(0xFFFF8A65), // orange
  'pronoun':     Color(0xFFBA68C8), // violet
  'preposition': Color(0xFF4DD0E1), // cyan
  'conjunction': Color(0xFFF06292), // pink
  'article':     Color(0xFFA5D6A7), // light green
  'interjection':Color(0xFFFFCC80), // light orange
  'other':       Color(0xFFB0BEC5), // blue-grey
};

// ── Minimal POS classifier ────────────────────────────────────────────────────
String _classifyPos(String word) {
  final w = word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');
  if (w.isEmpty) return 'other';

  const articles     = {'a','an','the'};
  const pronouns     = {'i','me','my','myself','we','our','us','you','your',
                        'he','him','his','she','her','it','its','they','them',
                        'their','who','whom','which','what','this','that',
                        'these','those'};
  const conjunctions = {'and','but','or','nor','for','yet','so','because',
                        'although','while','if','unless','since','when',
                        'though','whereas','after','before','until'};
  const prepositions = {'in','on','at','by','for','with','about','against',
                        'between','into','through','during','before','after',
                        'above','below','to','from','up','down','of','off',
                        'over','under','again','further','out'};
  const interjections= {'oh','ah','wow','hey','oops','ouch','ugh','hmm',
                        'yes','no','okay','ok'};

  if (articles.contains(w))      return 'article';
  if (pronouns.contains(w))      return 'pronoun';
  if (conjunctions.contains(w))  return 'conjunction';
  if (prepositions.contains(w))  return 'preposition';
  if (interjections.contains(w)) return 'interjection';

  // Pattern-based heuristics
  if (w.endsWith('ly') && w.length > 4)                   return 'adverb';
  if (w.endsWith('ing') && w.length > 4)                  return 'verb';
  if (w.endsWith('ed') && w.length > 4)                   return 'verb';
  if (w.endsWith('tion') || w.endsWith('sion') ||
      w.endsWith('ness') || w.endsWith('ment') ||
      w.endsWith('ity')  || w.endsWith('ism') ||
      w.endsWith('er')   || w.endsWith('or') ||
      w.endsWith('ist')  || w.endsWith('age'))             return 'noun';
  if (w.endsWith('ful') || w.endsWith('less') ||
      w.endsWith('ous')  || w.endsWith('ive') ||
      w.endsWith('able') || w.endsWith('ible') ||
      w.endsWith('ic')   || w.endsWith('al'))              return 'adjective';

  // Common short verbs
  const commonVerbs = {'is','are','was','were','be','been','being','have',
                       'has','had','do','does','did','will','would','shall',
                       'should','may','might','can','could','must','need',
                       'dare','ought','used','get','got','make','go','goes',
                       'went','come','came','say','said','know','think',
                       'take','see','look','want','give','use','find','tell',
                       'ask','seem','feel','try','call','keep','let','put',
                       'run','set','sit','stand','turn','show','play','move'};
  if (commonVerbs.contains(w))                             return 'verb';

  return 'noun'; // default for content words
}

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen>
    with SingleTickerProviderStateMixin {
  final _textSelectionService = TextSelectionService();
  final _syllableService = SyllableService();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final document = state.currentDocument;

        if (document == null) {
          return Scaffold(
            backgroundColor: _kSurface,
            appBar: AppBar(
              backgroundColor: _kBar,
              title: const Text(
                'Reading',
                style: TextStyle(color: _kOnSurface, fontFamily: 'OpenDyslexic'),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: _kOnSurface),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _kAccent),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading document...',
                    style: TextStyle(fontSize: 16, color: _kOnSurface,
                        fontFamily: 'OpenDyslexic'),
                  ),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: _kAccent),
                    label: const Text(
                      'Go Back',
                      style: TextStyle(color: _kAccent,
                          fontFamily: 'OpenDyslexic'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final backgroundColor = _getBackgroundColor(state.selectedBackgroundColor);
        final textColor       = _getTextColor(state.selectedTextColor);

        return Scaffold(
          backgroundColor: _kSurface,
          appBar: _buildAppBar(context, state, document.name),
          body: Column(
            children: [
              // ── Control panel ──────────────────────────────────────────────
              _buildControlPanel(context, state),

              // ── Reading area ───────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.0,
                      onInteractionUpdate: (d) {
                        if (d.scale != state.zoomLevel) {
                          context.read<AppBloc>().add(AdjustZoom(d.scale));
                        }
                      },
                      child: Container(
                        color: backgroundColor,
                        padding: const EdgeInsets.all(24),
                        width: MediaQuery.of(context).size.width,
                        child: SingleChildScrollView(
                          child: _buildText(context, state, document, textColor),
                        ),
                      ),
                    ),
                    if (state.isRulerEnabled)
                      ReadingRuler(
                        screenSize: MediaQuery.of(context).size,
                        initialPosition: state.rulerPosition,
                        onPositionChanged: (pos) =>
                            context.read<AppBloc>().add(UpdateRulerPosition(pos)),
                      ),
                    if (state.zoomLevel > 1.0)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _ZoomBadge(
                          zoom: state.zoomLevel,
                          onReset: () => context.read<AppBloc>().add(ResetZoom()),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Playback controls ──────────────────────────────────────────
              _buildPlaybackBar(context, state, document),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, state),
        );
      },
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AppState state, String title) {
    return AppBar(
      backgroundColor: _kBar,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _kOnSurface),
        onPressed: () {
          context.read<AppBloc>().add(StopTextToSpeech());
          Navigator.pop(context);
        },
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: _kOnSurface, fontSize: 14, fontFamily: 'OpenDyslexic'),
      ),
      actions: [
        IconButton(
          icon: Icon(
            state.useOpenDyslexic
                ? Icons.font_download
                : Icons.font_download_outlined,
            color: state.useOpenDyslexic ? _kAccent : _kOnSurface,
          ),
          tooltip: state.useOpenDyslexic
              ? 'Disable OpenDyslexic'
              : 'Enable OpenDyslexic',
          onPressed: () {
            context.read<AppBloc>().add(ToggleOpenDyslexic());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.useOpenDyslexic
                  ? 'Default font enabled'
                  : 'OpenDyslexic font enabled'),
              duration: const Duration(seconds: 1),
              backgroundColor: _kPrimary,
            ));
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: _kOnSurface),
          onPressed: () => _showSettingsDialog(context, state),
        ),
      ],
    );
  }

  // ── Control panel ──────────────────────────────────────────────────────────

  Widget _buildControlPanel(BuildContext context, AppState state) {
    return Container(
      color: _kBar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: state.isSoundEnabled ? Icons.volume_up : Icons.volume_off,
            label: 'Sound',
            isActive: state.isSoundEnabled,
            onTap: () => context.read<AppBloc>().add(ToggleSound()),
          ),
          _ControlButton(
            icon: Icons.straighten,
            label: 'Ruler',
            isActive: state.isRulerEnabled,
            onTap: () => context.read<AppBloc>().add(ToggleRuler()),
          ),
          _ControlButton(
            icon: Icons.highlight,
            label: 'Highlight',
            isActive: state.isHighlighted,
            onTap: () => context.read<AppBloc>().add(ToggleHighlight()),
          ),
        ],
      ),
    );
  }

  // ── Playback bar ───────────────────────────────────────────────────────────

  Widget _buildPlaybackBar(
      BuildContext context, AppState state, document) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          if (state.readingState != ReadingState.idle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Word: ${state.currentWordIndex + 1}',
                      style: const TextStyle(
                          color: _kOnSurface, fontSize: 12,
                          fontFamily: 'OpenDyslexic')),
                  const Spacer(),
                  Text(
                    state.readingState == ReadingState.playing
                        ? 'Playing'
                        : 'Paused',
                    style: const TextStyle(
                        color: _kAccent, fontSize: 12,
                        fontFamily: 'OpenDyslexic'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous,
                    color: _kOnSurface, size: 30),
                onPressed: () =>
                    context.read<AppBloc>().add(StopTextToSpeech()),
              ),
              IconButton(
                icon: const Icon(Icons.replay_10,
                    color: _kOnSurface, size: 30),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(
                  state.readingState == ReadingState.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: _kAccent,
                  size: 52,
                ),
                onPressed: () => _handlePlayPause(context, state, document),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10,
                    color: _kOnSurface, size: 30),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.skip_next,
                    color: _kOnSurface, size: 30),
                onPressed: () =>
                    context.read<AppBloc>().add(StopTextToSpeech()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePlayPause(BuildContext context, AppState state, document) {
    if (!state.isSoundEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enable sound first'),
        backgroundColor: _kPrimary,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    if (state.readingState == ReadingState.playing) {
      context.read<AppBloc>().add(PauseTextToSpeech());
    } else if (state.readingState == ReadingState.paused) {
      context.read<AppBloc>().add(ResumeTextToSpeech());
    } else if (document.content.isNotEmpty) {
      context
          .read<AppBloc>()
          .add(StartTextToSpeech(text: document.content));
    }
  }

  // ── Bottom navigation ──────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, AppState state) {
    return Container(
      color: _kBar,
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: _kOnSurface),
                onPressed: () {
                  context.read<AppBloc>().add(StopTextToSpeech());
                  Navigator.pop(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_alt, color: _kOnSurface),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<AppBloc>(),
                      child: const FilterScreen(),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: _kOnSurface),
                onPressed: () =>
                    _showSettingsDialog(context, context.read<AppBloc>().state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Text rendering ─────────────────────────────────────────────────────────

  Widget _buildText(BuildContext context, AppState state,
      dynamic document, Color textColor) {
    if (document.content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.text_snippet_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('No content available',
                style: TextStyle(fontSize: 16, color: Colors.grey[400],
                    fontFamily: 'OpenDyslexic')),
          ],
        ),
      );
    }

    final words = _textSelectionService.extractWords(document.content);
    String? fontFamily;
    if (state.useOpenDyslexic && _isLatinText(document.content)) {
      fontFamily = 'OpenDyslexic';
    }

    if (state.readingState == ReadingState.idle) {
      // Interactive mode: each word is tappable.
      return Wrap(
        children: words.map((word) {
          final clean = _textSelectionService.cleanWord(word);
          return _TappableWord(
            word: word,
            cleanWord: clean,
            textColor: textColor,
            fontSize: state.fontSize,
            fontFamily: fontFamily,
            lineSpacing: state.lineSpacing,
            letterSpacing: fontFamily == 'OpenDyslexic' ? state.letterSpacing : 0,
            isHighlighted: state.isHighlighted,
            onTap: () => _showWordDetail(context, clean),
          );
        }).toList(),
      );
    }

    // TTS-playing mode: highlight current word.
    return RichText(
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final index = entry.key;
          final word  = entry.value;
          final isCurrent = index == state.currentWordIndex;
          return TextSpan(
            text: '$word ',
            style: TextStyle(
              color: isCurrent ? const Color(0xFFE57373) : textColor,
              fontSize: state.fontSize,
              fontFamily: fontFamily,
              height: state.lineSpacing,
              backgroundColor: isCurrent
                  ? _kAccent.withOpacity(0.35)
                  : (state.isHighlighted
                      ? _kAccent.withOpacity(0.12)
                      : null),
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              letterSpacing:
                  fontFamily == 'OpenDyslexic' ? state.letterSpacing : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isLatinText(String text) {
    final sample = text.length > 100 ? text.substring(0, 100) : text;
    return RegExp(r'^[a-zA-Z0-9\s\p{P}]+$', unicode: true).hasMatch(sample);
  }

  // ── Word detail bottom-sheet ───────────────────────────────────────────────

  void _showWordDetail(BuildContext context, String word) {
    if (word.isEmpty) return;
    final syllables = _syllableService.breakIntoSyllables(word);
    final formatted = _syllableService.formatSyllables(syllables);
    final pos       = _classifyPos(word);
    final posColor  = _kPosColors[pos] ?? _kPosColors['other']!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (_, val, child) =>
            Opacity(opacity: val, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kPrimary.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Syllabified word
              Text(
                formatted,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'OpenDyslexic',
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 8),

              // Syllable count
              Text(
                '${syllables.length} syllable${syllables.length != 1 ? "s" : ""}',
                style: TextStyle(
                  color: _kOnSurface.withOpacity(0.55),
                  fontSize: 13,
                  fontFamily: 'OpenDyslexic',
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: _kAccent.withOpacity(0.25)),
              const SizedBox(height: 16),

              // POS badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: posColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: posColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: posColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pos[0].toUpperCase() + pos.substring(1),
                          style: TextStyle(
                            color: posColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Syllable chips
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: syllables.asMap().entries.map((e) {
                  final colours = [
                    _kAccent,
                    const Color(0xFF64B5F6),
                    const Color(0xFF81C784),
                    const Color(0xFFFFD54F),
                  ];
                  final c = colours[e.key % colours.length];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.withOpacity(0.6)),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: _kAccent,
                      fontFamily: 'OpenDyslexic'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings dialog (unchanged logic, refined style) ──────────────────────

  void _showSettingsDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<AppBloc>(),
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: _kSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Reading Settings',
                style: TextStyle(
                    color: _kOnSurface, fontFamily: 'OpenDyslexic')),
            content: SingleChildScrollView(
              child: BlocBuilder<AppBloc, AppState>(
                builder: (context, state) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _settingsLabel('Font Family'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['OpenDyslexic', 'Arial', 'Times New Roman',
                        'Georgia', 'Verdana'].map((font) {
                        final isSelected = state.fontFamily == font ||
                            (font == 'OpenDyslexic' && state.useOpenDyslexic);
                        return ChoiceChip(
                          label: Text(font,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : _kOnSurface)),
                          selected: isSelected,
                          selectedColor: _kPrimary,
                          backgroundColor: _kBar,
                          onSelected: (_) {
                            if (font == 'OpenDyslexic') {
                              if (!state.useOpenDyslexic) {
                                context.read<AppBloc>().add(ToggleOpenDyslexic());
                              }
                            } else {
                              if (state.useOpenDyslexic) {
                                context.read<AppBloc>().add(ToggleOpenDyslexic());
                              }
                              context.read<AppBloc>().add(ChangeFontFamily(font));
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _settingsDivider(),
                    _settingsSlider(
                      context: context,
                      label: 'Font Size',
                      value: state.fontSize,
                      displayValue: '${state.fontSize.toInt()}',
                      min: 12, max: 32, divisions: 20,
                      onChanged: (v) => context.read<AppBloc>().add(AdjustFontSize(v)),
                    ),
                    _settingsSlider(
                      context: context,
                      label: 'Line Spacing',
                      value: state.lineSpacing,
                      displayValue: '${state.lineSpacing.toStringAsFixed(1)}x',
                      min: 1, max: 3, divisions: 20,
                      onChanged: (v) =>
                          context.read<AppBloc>().add(AdjustLineSpacing(v)),
                    ),
                    if (state.useOpenDyslexic)
                      _settingsSlider(
                        context: context,
                        label: 'Letter Spacing',
                        value: state.letterSpacing,
                        displayValue: state.letterSpacing.toStringAsFixed(1),
                        min: 0, max: 2, divisions: 20,
                        onChanged: (v) =>
                            context.read<AppBloc>().add(AdjustLetterSpacing(v)),
                      ),
                    _settingsDivider(),
                    _settingsSlider(
                      context: context,
                      label: 'Overlay Opacity',
                      value: state.overlayOpacity,
                      displayValue: '${(state.overlayOpacity * 100).toInt()}%',
                      min: 0.5, max: 1, divisions: 10,
                      onChanged: (v) =>
                          context.read<AppBloc>().add(AdjustOverlayOpacity(v)),
                    ),
                    _settingsDivider(),
                    _settingsLabel('Audio Settings'),
                    const SizedBox(height: 8),
                    _settingsSlider(
                      context: context,
                      label: 'Reading Speed',
                      value: state.readingSpeed,
                      displayValue:
                          '${(state.readingSpeed * 2).toStringAsFixed(1)}x',
                      min: 0.1, max: 1, divisions: 9,
                      onChanged: (v) =>
                          context.read<AppBloc>().add(AdjustSpeed(v)),
                    ),
                    _settingsSlider(
                      context: context,
                      label: 'Volume',
                      value: state.volume,
                      displayValue:
                          '${(state.volume * 100).toInt()}%',
                      min: 0, max: 1, divisions: 10,
                      onChanged: (v) =>
                          context.read<AppBloc>().add(AdjustVolume(v)),
                    ),
                    if (state.availableVoices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _settingsLabel('Voice'),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        dropdownColor: _kBar,
                        value: state.selectedVoice,
                        hint: const Text('Default',
                            style: TextStyle(color: _kOnSurface)),
                        items: state.availableVoices
                            .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: _kOnSurface)),
                            ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            context.read<AppBloc>().add(SelectVoice(val));
                          }
                        },
                      ),
                    ],
                    _settingsDivider(),
                    _settingsLabel('Zoom Level'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: _kOnSurface),
                          onPressed: () {
                            final z = (state.zoomLevel - 0.1).clamp(1.0, 3.0);
                            context.read<AppBloc>().add(AdjustZoom(z));
                          },
                        ),
                        Expanded(
                          child: Slider(
                            value: state.zoomLevel,
                            min: 1, max: 3, divisions: 20,
                            activeColor: _kAccent,
                            onChanged: (v) =>
                                context.read<AppBloc>().add(AdjustZoom(v)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: _kOnSurface),
                          onPressed: () {
                            final z = (state.zoomLevel + 0.1).clamp(1.0, 3.0);
                            context.read<AppBloc>().add(AdjustZoom(z));
                          },
                        ),
                      ],
                    ),
                    if (state.zoomLevel > 1.0)
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              context.read<AppBloc>().add(ResetZoom()),
                          child: const Text('Reset Zoom',
                              style: TextStyle(color: _kAccent,
                                  fontFamily: 'OpenDyslexic')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close',
                    style: TextStyle(
                        color: _kAccent, fontFamily: 'OpenDyslexic')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings helpers ───────────────────────────────────────────────────────

  Widget _settingsLabel(String text) => Text(text,
      style: const TextStyle(
          color: _kOnSurface, fontWeight: FontWeight.bold,
          fontFamily: 'OpenDyslexic'));

  Widget _settingsDivider() =>
      Divider(color: _kAccent.withOpacity(0.2), height: 24);

  Widget _settingsSlider({
    required BuildContext context,
    required String label,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: _kOnSurface,
                    fontFamily: 'OpenDyslexic')),
            Text(displayValue,
                style: const TextStyle(
                    color: _kAccent, fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic')),
          ],
        ),
        Slider(
          value: value,
          min: min, max: max, divisions: divisions,
          activeColor: _kAccent,
          inactiveColor: _kAccent.withOpacity(0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── Colour helpers (unchanged) ─────────────────────────────────────────────

  Color _getBackgroundColor(int index) {
    const colors = [
      Color(0xFFF5F0FF),
      Color(0xFF1F1A2E),
      Color(0xFFEDE0F7),
      Color(0xFFD4B8E8),
      Colors.white,
      Color(0xFFFFF8E1),
      Color(0xFFE8E8F0),
    ];
    return index < colors.length ? colors[index] : const Color(0xFFF5F0FF);
  }

  Color _getTextColor(int index) {
    const colors = [
      Color(0xFF1F1A2E),
      Color(0xFF000000),
      Color(0xFF5C4080),
      Color(0xFF7B4FA6),
      Color(0xFF4A3060),
      Colors.white,
      Color(0xFF3D2B5E),
    ];
    return index < colors.length ? colors[index] : const Color(0xFF1F1A2E);
  }
}

// ── Tappable word widget ──────────────────────────────────────────────────────

class _TappableWord extends StatefulWidget {
  final String word;
  final String cleanWord;
  final Color textColor;
  final double fontSize;
  final String? fontFamily;
  final double lineSpacing;
  final double letterSpacing;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _TappableWord({
    required this.word,
    required this.cleanWord,
    required this.textColor,
    required this.fontSize,
    required this.fontFamily,
    required this.lineSpacing,
    required this.letterSpacing,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_TappableWord> createState() => _TappableWordState();
}

class _TappableWordState extends State<_TappableWord>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: () {
        _ctrl.reverse();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Text(
            '${widget.word} ',
            style: TextStyle(
              color: widget.textColor,
              fontSize: widget.fontSize,
              fontFamily: widget.fontFamily,
              height: widget.lineSpacing,
              letterSpacing: widget.letterSpacing,
              backgroundColor: widget.isHighlighted
                  ? _kAccent.withOpacity(0.12)
                  : null,
              decoration: widget.cleanWord.isNotEmpty
                  ? TextDecoration.underline
                  : null,
              decorationColor: _kAccent.withOpacity(0.35),
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Zoom badge ────────────────────────────────────────────────────────────────

class _ZoomBadge extends StatelessWidget {
  final double zoom;
  final VoidCallback onReset;
  const _ZoomBadge({required this.zoom, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text('${(zoom * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onReset,
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Control button ────────────────────────────────────────────────────────────

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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _kPrimary : _kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _kPrimary : _kAccent.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18,
                color: isActive ? Colors.white : _kOnSurface),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.white : _kOnSurface,
                  fontFamily: 'OpenDyslexic',
                )),
          ],
        ),
      ),
    );
  }
}