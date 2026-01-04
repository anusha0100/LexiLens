import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text(
          'Privacy Policy\nComing Soon!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }
}
