import 'package:flutter/material.dart';
import 'package:lexilens/main.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late AnimationController _floatController;
  late AnimationController _glowController;

  late Animation<double> _headingOpacity;
  late Animation<Offset> _headingSlide;
  late Animation<double> _cardOpacity;
  late Animation<double> _cardScale;
  late Animation<double> _float;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _glowController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);

    _headingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.0, 0.55)));
    _headingSlide   = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _cardOpacity    = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.35, 1.0)));
    _cardScale      = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _enterController, curve: const Interval(0.35, 1.0, curve: Curves.easeOutBack)));
    _float          = Tween<double>(begin: -7.0, end: 7.0).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _glow           = Tween<double>(begin: 0.15, end: 0.35).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final cardBg    = isDark ? AppColors.darkCard     : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText     : AppColors.lightText;
    final subColor  = isDark ? AppColors.darkSubtext  : AppColors.lightSubtext;

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            
            SlideTransition(
              position: _headingSlide,
              child: FadeTransition(
                opacity: _headingOpacity,
                child: Column(
                  children: [
                    Text(
                      'Hi, Welcome\nto LexiLens',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        height: 1.3,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your Easy Reader',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: subColor,
                        fontFamily: 'OpenDyslexic',
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            
            Expanded(
              child: ScaleTransition(
                scale: _cardScale,
                child: FadeTransition(
                  opacity: _cardOpacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_floatController, _glowController]),
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _float.value),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withOpacity(_glow.value),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Image.asset('assets/l6.png', fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}