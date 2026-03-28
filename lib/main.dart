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
            
            // Light Theme Configuration
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              primaryColor: const Color(0xFFB789DA),
              scaffoldBackgroundColor: Colors.white,
              fontFamily: 'OpenDyslexic', // Corrected placement
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFB789DA),
                primary: const Color(0xFFB789DA),
                brightness: Brightness.light,
              ),
            ),

            // Dark Theme Configuration
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              primaryColor: const Color(0xFFB789DA),
              scaffoldBackgroundColor: const Color(0xFF1F1A2E),
              fontFamily: 'OpenDyslexic', // Corrected placement
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFB789DA),
                primary: const Color(0xFFB789DA),
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2D2545),
                foregroundColor: Color(0xFFEDE0F7),
                elevation: 0,
              ),
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