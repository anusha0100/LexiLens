import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/firebase_options.dart';
import 'package:lexilens/screens/auth_check_screen.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
    final response = await http.get(
      Uri.parse('${MongoDBService.baseUrl.replaceAll('/api', '')}/health'),
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw Exception('Connection timeout');
      },
    );
    
    if (response.statusCode == 200) {
      print('Backend connection successful');
      print('Response: ${response.body}');
    } else {
      print('Backend returned status: ${response.statusCode}');
    }
  } catch (e) {
    print('Backend connection failed: $e');
    print('he app will use mock data. Please check:');
    print('   1. Is the backend server running?');
    print('   2. Is the backend URL correct in mongodb_service.dart?');
    print('   3. Can the device reach the backend server?');
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
      child: MaterialApp(
        title: 'LexiLens',
        theme: ThemeData(
          primaryColor: const Color(0xFFB789DA),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'OpenDyslexic',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB789DA),
            primary: const Color(0xFFB789DA),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthCheckScreen(),
      ),
    );
  }
}
