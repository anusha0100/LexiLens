// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lexilens/main.dart';

class OnboardingPage extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _floatController;

  late Animation<double>  _imageScale;
  late Animation<double>  _imageOpacity;
  late Animation<Offset>  _titleSlide;
  late Animation<double>  _titleOpacity;
  late Animation<Offset>  _descSlide;
  late Animation<double>  _descOpacity;
  late Animation<double>  _float;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

    _imageScale   = Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack));
    _imageOpacity = Tween<double>(begin: 0.0,  end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.0, 0.6)));
    _titleSlide   = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic)));
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.25, 0.75)));
    _descSlide    = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic)));
    _descOpacity  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.45, 1.0)));
    _float        = Tween<double>(begin: -8.0, end: 8.0).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final textColor    = isDark ? AppColors.darkText    : AppColors.lightText;
    final subColor     = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardBg       = isDark ? AppColors.darkCard    : AppColors.lightSurface;
    final glowColor    = AppColors.accent.withOpacity(isDark ? 0.18 : 0.12);

    return Container(
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),


          ScaleTransition(
            scale: _imageScale,
            child: FadeTransition(
              opacity: _imageOpacity,
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _float.value),
                  child: child,
                ),
                child: Container(
                  width:  MediaQuery.of(context).size.width * 0.58,
                  height: MediaQuery.of(context).size.width * 0.58,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.12),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: glowColor, blurRadius: 30, offset: const Offset(0, 12)),
                      BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 60, spreadRadius: 10),
                    ],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Image.asset(widget.imagePath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          const Spacer(),

          SlideTransition(
            position: _titleSlide,
            child: FadeTransition(
              opacity: _titleOpacity,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.3,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          SlideTransition(
            position: _descSlide,
            child: FadeTransition(
              opacity: _descOpacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: subColor,
                    height: 1.55,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}