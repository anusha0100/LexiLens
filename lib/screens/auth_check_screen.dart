import 'package:flutter/material.dart';
import 'package:lexilens/screens/home_screen.dart';
import 'package:lexilens/screens/onboarding_screen.dart';
import 'package:lexilens/services/auth_service.dart';

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    if (authService.isLoggedIn) {
      return const HomeScreen();
    } else {
      return const OnboardingScreen();
    }
  }
}