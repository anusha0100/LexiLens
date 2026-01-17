import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB789DA), Color(0xFF9B6FC4)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            const Text(
              'Hi, Welcome\nto LexiLens',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Easy Reader',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 60),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4C3E3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/l6.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100), 
          ],
        ),
      ),
    );
  }
}