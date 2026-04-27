import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/bloc/bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/firebase_options.dart';
import 'package:lexilens/screens/auth_check_screen.dart';
import 'package:lexilens/screens/onboarding_screen.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  await _testBackendConnection();
  runApp(const LexiLens());
}

Future<void> _testBackendConnection() async {
  print('Testing backend connection...');
  print('Backend URL: ${MongoDBService.baseUrl}');
  try {
    final response = await http
        .get(Uri.parse('${MongoDBService.baseUrl.replaceAll('/api', '')}/health'))
        .timeout(const Duration(seconds: 5), onTimeout: () => throw Exception('Connection timeout'));
    if (response.statusCode == 200) {
      print('Backend connection successful');
    } else {
      print('Backend returned status: ${response.statusCode}');
    }
  } catch (e) {
    print('Backend connection failed: $e');
  }
}

// ─── Centralised colour tokens ────────────────────────────────────────────────
class AppColors {
  // Brand
  static const purple      = Color(0xFF7B4FA6);
  static const accent      = Color(0xFFB789DA);
  static const accentLight = Color(0xFFD4A8F0);

  // Light surface
  static const lightBg        = Color(0xFFF7F3FF);
  static const lightSurface   = Colors.white;
  static const lightCard      = Color(0xFFF0E8FC);
  static const lightText      = Color(0xFF2D1B4E);
  static const lightSubtext   = Color(0xFF7A6A8E);

  // Dark surface
  static const darkBg         = Color(0xFF0F0D1A);
  static const darkSurface    = Color(0xFF1A1528);
  static const darkCard       = Color(0xFF231E36);
  static const darkNavBar     = Color(0xFF1A1528);
  static const darkText       = Color(0xFFEDE0F7);
  static const darkSubtext    = Color(0xFF9E8AB5);
  static const darkBorder     = Color(0xFF3A3055);
}

class LexiLens extends StatelessWidget {
  const LexiLens({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => OnboardingBloc()),
        BlocProvider(
          create: (context) => AppBloc()..add(LoadDocuments()),
        ),
      ],
      child: BlocBuilder<AppBloc, AppState>(
        buildWhen: (prev, next) => prev.isDarkMode != next.isDarkMode,
        builder: (context, state) {
          return MaterialApp(
            title: 'LexiLens',
            themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            // ── Light Theme ────────────────────────────────────────────
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              primaryColor: AppColors.purple,
              scaffoldBackgroundColor: AppColors.lightBg,
              fontFamily: 'OpenDyslexic',
              colorScheme: const ColorScheme.light(
                primary: AppColors.purple,
                secondary: AppColors.accent,
                surface: AppColors.lightSurface,
                background: AppColors.lightBg,
                onPrimary: Colors.white,
                onSurface: AppColors.lightText,
                onBackground: AppColors.lightText,
              ),
              cardTheme: CardThemeData(
                color: AppColors.lightSurface,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.lightBg,
                foregroundColor: AppColors.lightText,
                elevation: 0,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.lightCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE0D4F5), width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.8)),
                hintStyle: const TextStyle(color: AppColors.lightSubtext, fontFamily: 'OpenDyslexic', fontSize: 13),
              ),
            ),

            // ── Dark Theme ─────────────────────────────────────────────
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              primaryColor: AppColors.purple,
              scaffoldBackgroundColor: AppColors.darkBg,
              fontFamily: 'OpenDyslexic',
              colorScheme: const ColorScheme.dark(
                primary: AppColors.accent,
                secondary: AppColors.accentLight,
                surface: AppColors.darkSurface,
                background: AppColors.darkBg,
                onPrimary: Colors.white,
                onSurface: AppColors.darkText,
                onBackground: AppColors.darkText,
                surfaceVariant: AppColors.darkCard,
              ),
              cardTheme: CardThemeData(
                color: AppColors.darkCard,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.darkBorder, width: 1),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.darkSurface,
                foregroundColor: AppColors.darkText,
                elevation: 0,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.8)),
                hintStyle: const TextStyle(color: AppColors.darkSubtext, fontFamily: 'OpenDyslexic', fontSize: 13),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: AppColors.darkNavBar,
                selectedItemColor: AppColors.accentLight,
                unselectedItemColor: AppColors.darkSubtext,
                elevation: 0,
              ),
              dividerColor: AppColors.darkBorder,
            ),

            debugShowCheckedModeBanner: false,
            home: const AuthCheckScreen(),
            routes: {
              '/login': (context) => const OnboardingScreen(),
            },
          );
        },
      ),
    );
  }
}