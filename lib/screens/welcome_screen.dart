import 'package:flutter/material.dart';

// FIX: Improved welcome screen layout.
// • Reduced excessive bottom whitespace (SizedBox height 100 → Spacer).
// • Illustration card has consistent padding and gentle drop-shadow.
// • Typography tightened: heading weight up, subtitle opacity softer.

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB789DA), Color(0xFF7B4FA6)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // ── Heading ────────────────────────────────────────────────────
            const Text(
              'Hi, Welcome\nto LexiLens',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
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
                color: Colors.white.withOpacity(0.85),
                fontFamily: 'OpenDyslexic',
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 40),

            // ── Illustration card ──────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4C3E3),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Image.asset(
                        'assets/l6.png',
                        fit: BoxFit.contain,
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