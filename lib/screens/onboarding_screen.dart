import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/bloc.dart';
import 'package:lexilens/bloc/events.dart';
import 'package:lexilens/bloc/states.dart';
import 'package:lexilens/screens/auth_landing_screen.dart';
import 'package:lexilens/screens/splash_screen.dart';
import 'package:lexilens/screens/welcome_screen.dart';
import 'package:lexilens/widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skipToWelcome() {
     context.read<OnboardingBloc>().add(GoToPage(4));
    if (_pageController.hasClients) {
      _pageController.jumpToPage(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            state.currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, state) {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          context.read<OnboardingBloc>().add(
                                GoToPage(index),
                              );
                        },
                        children: const [
                          SplashScreen(),
                          OnboardingPage(
                            title: 'Read printed text\nwith confidence',
                            description:
                                "Lexilens helps you read any\nprinted material using your\nphone's camera and\ndyslexia-friendly tools",
                            imagePath: 'assets/l1.png',
                          ),
                          OnboardingPage(
                            title: 'Real-time\nreading assistance',
                            description:
                                'Get instant text overlay, tap to\nhear words spoken aloud, and\nuse focus tools to read more easily',
                            imagePath: 'assets/l2.png',
                          ),
                          OnboardingPage(
                            title: 'Personalized for\nyour needs',
                            description:
                                'Customize fonts, colors and speech settings\nthat work best for you -\nall synced across your devices',
                            imagePath: 'assets/l3.png',
                          ),
                          WelcomeScreen(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          if (state.currentPage < state.totalPages - 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                state.totalPages -
                                    1, 
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  width: state.currentPage == index ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: state.currentPage == index
                                        ? const Color(0xFFB789DA)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (state.currentPage > 0 &&
                              state.currentPage < state.totalPages - 1)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  context
                                      .read<OnboardingBloc>()
                                      .add(NextPage());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB789DA),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                              ),
                            ),
                          // Show Get Started button for welcome screen
                          if (state.currentPage == state.totalPages - 1)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  context
                                      .read<OnboardingBloc>()
                                      .add(CompleteOnboarding());
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AuthLandingScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFB789DA),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Skip Button 
                if (state.currentPage > 0 &&
                    state.currentPage < state.totalPages - 1)
                  Positioned(
                    top: 60,
                    right: 10,
                    child: SafeArea(
                      child: TextButton(
                        onPressed: _skipToWelcome,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB789DA),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}