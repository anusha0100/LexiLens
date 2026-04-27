import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/bloc.dart';
import 'package:lexilens/bloc/events.dart';

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
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _pulse;
  late Animation<double> _particleOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _subtitleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5)));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn));
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _particleOpacity = Tween<double>(begin: 0.15, end: 0.45).animate(CurvedAnimation(parent: _particleController, curve: Curves.easeInOut));

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
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => context.read<OnboardingBloc>().add(NextPage()),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C3AED), Color(0xFFB789DA), Color(0xFFD4A8F0)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) => Opacity(opacity: _particleOpacity.value, child: child!),
                child: Stack(children: [
                  Positioned(top: size.height * 0.07, left: size.width * 0.05, child: _circle(80, 0.15)),
                  Positioned(top: size.height * 0.14, right: size.width * 0.07, child: _circle(50, 0.12)),
                  Positioned(bottom: size.height * 0.22, left: size.width * 0.08, child: _circle(60, 0.10)),
                  Positioned(bottom: size.height * 0.08, right: size.width * 0.10, child: _circle(100, 0.08)),
                  Positioned(top: size.height * 0.40, right: size.width * 0.03, child: _circle(35, 0.14)),
                ]),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_logoController, _pulseController]),
                      builder: (context, child) => Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(scale: _logoScale.value * _pulse.value, child: child),
                      ),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 35, spreadRadius: 8)],
                        ),
                        child: ClipOval(child: Image.asset('assets/l5.png', fit: BoxFit.cover)),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: const Text(
                          'LexiLens',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            fontFamily: 'OpenDyslexic',
                            shadows: [Shadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 5))],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: const Text(
                          'Reading made for you',
                          style: TextStyle(fontSize: 15, color: Colors.white, fontFamily: 'OpenDyslexic', letterSpacing: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 70),
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Opacity(opacity: 0.45 + (_pulseController.value * 0.55), child: child!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app, color: Colors.white70, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Tap anywhere to continue',
                              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8), fontFamily: 'OpenDyslexic', letterSpacing: 0.3),
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

  Widget _circle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
  );
}