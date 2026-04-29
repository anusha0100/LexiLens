import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/bloc.dart';
import 'package:lexilens/bloc/events.dart';
import 'package:lexilens/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _subtitleController;
  late AnimationController _pulseController;
  late AnimationController _orbController;
  late AnimationController _shimmerController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _pulse;
  late Animation<double> _orbScale;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    _logoController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _subtitleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulseController    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _orbController      = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _shimmerController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

    _logoScale     = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity   = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5)));
    _textSlide     = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));
    _textOpacity   = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn));
    _pulse         = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _orbScale      = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut));
    _shimmer       = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _logoController.forward(); });
    Future.delayed(const Duration(milliseconds: 700), () { if (mounted) _textController.forward(); });
    Future.delayed(const Duration(milliseconds: 1100), () { if (mounted) _subtitleController.forward(); });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _subtitleController.dispose();
    _pulseController.dispose();
    _orbController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;

    final bgColor      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surfaceColor = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final textColor    = isDark ? AppColors.darkText     : AppColors.lightText;
    final subColor     = isDark ? AppColors.darkSubtext  : AppColors.lightSubtext;
    final orbColor     = isDark ? AppColors.accent.withOpacity(0.08) : AppColors.purple.withOpacity(0.06);

    return GestureDetector(
      onTap: () => context.read<OnboardingBloc>().add(NextPage()),
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Stack(
            children: [
              
              AnimatedBuilder(
                animation: _orbController,
                builder: (_, __) => Stack(
                  children: [
                    Positioned(
                      top: size.height * 0.05,
                      left: -size.width * 0.15,
                      child: Transform.scale(
                        scale: _orbScale.value,
                        child: _orb(size.width * 0.55, orbColor),
                      ),
                    ),
                    Positioned(
                      bottom: size.height * 0.1,
                      right: -size.width * 0.1,
                      child: Transform.scale(
                        scale: 1.3 - (_orbScale.value * 0.3),
                        child: _orb(size.width * 0.5, orbColor),
                      ),
                    ),
                    Positioned(
                      top: size.height * 0.42,
                      right: size.width * 0.02,
                      child: Transform.scale(
                        scale: _orbScale.value * 0.8 + 0.2,
                        child: _orb(size.width * 0.22, AppColors.accentLight.withOpacity(0.05)),
                      ),
                    ),
                  ],
                ),
              ),


              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with pulse
                    AnimatedBuilder(
                      animation: Listenable.merge([_logoController, _pulseController]),
                      builder: (_, child) => Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(scale: _logoScale.value * _pulse.value, child: child),
                      ),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: surfaceColor,
                          border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withOpacity(isDark ? 0.25 : 0.18), blurRadius: 40, spreadRadius: 4),
                          ],
                        ),
                        child: ClipOval(child: Image.asset('assets/l5.png', fit: BoxFit.cover)),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title with shimmer effect
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (_, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: isDark
                                ? [AppColors.accent, AppColors.accentLight, AppColors.accent]
                                : [AppColors.purple, AppColors.accent, AppColors.purple],
                            stops: [
                              (_shimmer.value - 0.3).clamp(0.0, 1.0),
                              _shimmer.value.clamp(0.0, 1.0),
                              (_shimmer.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds),
                          child: child!,
                        );
                      },
                      child: SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Text(
                            'LexiLens',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              fontFamily: 'OpenDyslexic',
                              shadows: [Shadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 4))],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Subtitle pill
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(isDark ? 0.15 : 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          'Reading made for you',
                          style: TextStyle(fontSize: 15, color: isDark ? AppColors.darkText : AppColors.lightText, fontFamily: 'OpenDyslexic', letterSpacing: 0.4),
                        ),
                      ),
                    ),

                    const SizedBox(height: 70),

                    
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (_, child) => Opacity(opacity: 0.45 + (_pulseController.value * 0.55), child: child!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, color: subColor, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Tap anywhere to continue',
                              style: TextStyle(fontSize: 13, color: subColor, fontFamily: 'OpenDyslexic', letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}