import 'package:flutter/material.dart';
import 'package:lexilens/screens/home_screen.dart';
import 'package:lexilens/screens/onboarding_screen.dart';
import 'package:lexilens/services/auth_service.dart';

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    // Check if user is already logged in
    if (authService.isLoggedIn) {
      // User is logged in, go to home screen
      return const HomeScreen();
    } else {
      // User is not logged in, show onboarding
      return const OnboardingScreen();
    }
  }
}