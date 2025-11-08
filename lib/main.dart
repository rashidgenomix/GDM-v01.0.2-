import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:germplasmx/screens/login_screen.dart';
import 'package:germplasmx/screens/signup_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth/auth_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const GermplasmApp(),
    ),
  );
}

class GermplasmApp extends StatelessWidget {
  const GermplasmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Germplasm Data Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Home is always shown first
    );
  }
}
