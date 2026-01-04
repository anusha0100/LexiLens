import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Terms of Service',
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
          'Terms of Service\nComing Soon!',
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