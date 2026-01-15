import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/bloc.dart';
import 'package:lexilens/bloc/app_bloc.dart';
import 'package:lexilens/firebase_options.dart';
import 'package:lexilens/screens/auth_check_screen.dart';
import 'package:lexilens/services/mongodb_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize MongoDB Service (singleton pattern, so just accessing initializes it)
  // The service will use the baseUrl defined in the class
  final mongoService = MongoDBService();
  print('✅ MongoDB Service initialized');
  
  runApp(const LexiLens());
}

class LexiLens extends StatelessWidget {
  const LexiLens({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => OnboardingBloc()),
        BlocProvider(create: (context) => AppBloc()),
      ],
      child: MaterialApp(
        title: 'LexiLens',
        theme: ThemeData(
          primaryColor: const Color(0xFFB789DA),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'OpenDyslexic',
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthCheckScreen(),
      ),
    );
  }
}

