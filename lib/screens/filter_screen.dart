// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';

// FIX: Filter selections now persist globally.
//
// Previous behaviour:
//   • _PartOfSpeechToggle kept its own local `_isEnabled` bool that was never
//     written to the bloc — toggling a POS had zero effect on the reading
//     screen and the state was lost every time the widget was rebuilt.
//   • SaveFilterSettings was a no-op.
//
// New behaviour:
//   • AppState gains `posEnabled` (Map<String,bool>) tracking which POS are on.
//   • Every toggle immediately fires TogglePos(label) to the AppBloc.
//   • AppBloc persists the map via _saveUserSetting / _loadUserSettings so it
//     survives app restarts.
//   • The SAVE button calls SaveFilterSettings which writes the current colour
//     and POS selections to the backend in one shot.
//
// NOTE: AppState / AppBloc changes are in their own files below.  This file
// only changes the UI wiring.

class FilterScreen extends StatelessWidget {
  const FilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Filters',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontFamily: 'OpenDyslexic',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final cardColor = theme.brightness == Brightness.dark
              ? const Color(0xFF2A2440)
              : const Color(0xFFF5F5F5);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Background colour picker ─────────────────────────
                      _SectionCard(
                        cardColor: cardColor,
                        icon: Icons.palette,
                        title: 'Background Color',
                        colorScheme: colorScheme,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(
                            7,
                            (i) => _ColorCircle(
                              color: _bgColor(i),
                              colorName: _bgName(i),
                              isSelected: state.selectedBackgroundColor == i,
                              onTap: () => context
                                  .read<AppBloc>()
                                  .add(ChangeBackgroundColor(i)),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Text colour picker ───────────────────────────────
                      _SectionCard(
                        cardColor: cardColor,
                        icon: Icons.text_fields,
                        title: 'Text Color',
                        colorScheme: colorScheme,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(
                            7,
                            (i) => _ColorCircle(
                              color: _txColor(i),
                              colorName: _txName(i),
                              isSelected: state.selectedTextColor == i,
                              onTap: () => context
                                  .read<AppBloc>()
                                  .add(ChangeTextColor(i)),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Parts of speech ──────────────────────────────────
                      Text(
                        'Color Coded Parts of Speech',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic',
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggles persist globally across the app',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.45),
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FIX: Each toggle reads from state.posEnabled and fires
                      // TogglePos when changed — no more lost local state.
                      _posRow(context, state, cardColor,
                        label1: 'Noun',      color1: const Color(0xFF64B5F6),
                        label2: 'Adjectives',color2: const Color(0xFFE8BFD5),
                      ),
                      const SizedBox(height: 12),
                      _posRow(context, state, cardColor,
                        label1: 'Verb',      color1: const Color(0xFF81C784),
                        label2: 'Adverbs',   color2: const Color(0xFFFF8A65),
                      ),
                      const SizedBox(height: 12),
                      _posRow(context, state, cardColor,
                        label1: 'Pronoun',   color1: const Color(0xFFBA68C8),
                        label2: 'Articles',  color2: const Color(0xFFFDD835),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Save button ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // FIX: SaveFilterSettings now actually writes everything
                      // to the backend (see app_bloc.dart).
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

  // ── POS row helper ──────────────────────────────────────────────────────────

  Widget _posRow(
    BuildContext context,
    AppState state,
    Color cardColor, {
    required String label1,
    required Color  color1,
    required String label2,
    required Color  color2,
  }) {
    return Row(
      children: [
        Expanded(
          child: _PosToggle(
            label:     label1,
            color:     color1,
            cardColor: cardColor,
            isEnabled: state.posEnabled[label1.toLowerCase()] ?? false,
            onChanged: (v) =>
                context.read<AppBloc>().add(TogglePos(label1.toLowerCase())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PosToggle(
            label:     label2,
            color:     color2,
            cardColor: cardColor,
            isEnabled: state.posEnabled[label2.toLowerCase()] ?? false,
            onChanged: (v) =>
                context.read<AppBloc>().add(TogglePos(label2.toLowerCase())),
          ),
        ),
      ],
    );
  }

  // ── Colour look-ups ─────────────────────────────────────────────────────────

  Color _bgColor(int i) {
    const c = [
      Color(0xFFF0F022), Color(0xFF1F1F39), Color(0xFFB789DA),
      Color(0xFFB685CA), Colors.white,      Color(0xFFFFF8E1),
      Color(0xFFE8E8E8),
    ];
    return i < c.length ? c[i] : Colors.grey;
  }

  String _bgName(int i) {
    const n = ['F0F022','1F1F39','B789DA','B685CA','FFFFFF','FFF8E1','E8E8E8'];
    return i < n.length ? n[i] : '';
  }

  Color _txColor(int i) {
    const c = [
      Color(0xFF1F1F39), Color(0xFF000000), Color(0xFF858597),
      Color(0xFFB789DA), Color(0xFFB7B9DA), Colors.white,
      Color(0xFF686897),
    ];
    return i < c.length ? c[i] : Colors.grey;
  }

  String _txName(int i) {
    const n = ['1F1F39','000000','858597','B789DA','B7B9DA','FFFFFF','686897'];
    return i < n.length ? n[i] : '';
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Color cardColor;
  final IconData icon;
  final String title;
  final ColorScheme colorScheme;
  final Widget child;

  const _SectionCard({
    required this.cardColor,
    required this.icon,
    required this.title,
    required this.colorScheme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFB789DA)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── POS toggle (stateless — driven entirely by AppBloc) ───────────────────────

class _PosToggle extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  cardColor;
  final bool   isEnabled;
  final ValueChanged<bool> onChanged;

  const _PosToggle({
    required this.label,
    required this.color,
    required this.cardColor,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? color : Colors.grey.withOpacity(0.35),
          width: isEnabled ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isEnabled ? FontWeight.bold : FontWeight.w600,
                fontFamily: 'OpenDyslexic',
                color: isEnabled
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}

// ── Colour circle ─────────────────────────────────────────────────────────────

class _ColorCircle extends StatelessWidget {
  final Color  color;
  final String colorName;
  final bool   isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.colorName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
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
                color: isSelected
                    ? const Color(0xFFB789DA)
                    : Colors.grey.withOpacity(0.4),
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
            style: TextStyle(
              fontSize: 10,
              color: labelColor,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }
}