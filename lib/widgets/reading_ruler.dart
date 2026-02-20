// widgets/reading_ruler.dart
import 'package:flutter/material.dart';

class ReadingRuler extends StatefulWidget {
  final Size screenSize;
  final Function(double) onPositionChanged;
  final double initialPosition;
  final Color color;
  final double opacity;

  const ReadingRuler({
    super.key,
    required this.screenSize,
    required this.onPositionChanged,
    this.initialPosition = 0.5,
    this.color = const Color(0xFFB789DA),
    this.opacity = 0.7,
  });

  @override
  State<ReadingRuler> createState() => _ReadingRulerState();
}

class _ReadingRulerState extends State<ReadingRuler> {
  late double _position;
  final double _rulerHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition * widget.screenSize.height;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: _position - _rulerHeight / 2,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = (_position + details.delta.dy)
                .clamp(_rulerHeight / 2, widget.screenSize.height - _rulerHeight / 2);
            widget.onPositionChanged(_position / widget.screenSize.height);
          });
        },
        child: Column(
          children: [
            // Top fade
            Container(
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0),
                    Colors.black.withOpacity(widget.opacity * 0.5),
                  ],
                ),
              ),
            ),
            // Main ruler area
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(widget.opacity * 0.3),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: widget.color.withOpacity(widget.opacity),
                    width: 2,
                  ),
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(widget.opacity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Bottom fade
            Container(
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(widget.opacity * 0.5),
                    Colors.black.withOpacity(0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}