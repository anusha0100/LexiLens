import 'package:flutter/material.dart';
import 'package:lexilens/screens/sign_up_screen.dart';
import 'package:lexilens/screens/log_in_screen.dart';

// FIX: Redesigned pre-login landing screen.
// Changes vs original:
//  • Full-height gradient background (matches the brand purple palette).
//  • Logo + wordmark lifted into a proper hero section at the top.
//  • Illustration centred in a rounded card with subtle shadow.
//  • Tagline and sub-copy use a clear typographic hierarchy.
//  • Buttons are larger, bolder, and correctly spaced.
//  • "Already have an account?" row replaced with a cleaner inline link.
//  • All existing asset paths preserved.

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  static const _kPurple     = Color(0xFF7B4FA6);
  static const _kAccent     = Color(0xFFB789DA);
  static const _kLightAccent = Color(0xFFD4C3E3);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [Color(0xFFF5EEFF), Color(0xFFEDD9FF), Color(0xFFFFFFFF)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // ── Brand mark ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'L',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'LexiLens',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                        color: _kPurple,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ── Hero illustration ─────────────────────────────────────────
                Container(
                  width: size.width * 0.78,
                  height: size.width * 0.72,
                  decoration: BoxDecoration(
                    color: _kLightAccent.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Image.asset(
                        'assets/l5.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Headlines ────────────────────────────────────────────────
                const Text(
                  'Read with confidence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic',
                    color: Color(0xFF2D1B4E),
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Your pocket reading assistant\nfor everyday challenges',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Colors.grey[600],
                    fontFamily: 'OpenDyslexic',
                  ),
                ),

                const Spacer(),

                // ── Sign Up button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignUpScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'OpenDyslexic',
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Log In ghost button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LogInScreen(),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPurple,
                      side: const BorderSide(color: _kAccent, width: 1.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}