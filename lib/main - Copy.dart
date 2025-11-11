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

/// Handles global back button behavior:
/// - Any screen except Home → navigates to Home
/// - Home → double-tap to exit
class BackButtonHandler extends StatefulWidget {
  final Widget child;
  const BackButtonHandler({super.key, required this.child});

  @override
  State<BackButtonHandler> createState() => _BackButtonHandlerState();
}

class _BackButtonHandlerState extends State<BackButtonHandler> {
  DateTime? _lastBackPressed;

  Future<bool> _onWillPop() async {
    final navigator = Navigator.of(context);

    // If current route is not HomeScreen, go back to HomeScreen
    if (navigator.canPop()) {
      // Pop everything until HomeScreen
      navigator.popUntil((route) => route.isFirst);
      return false; // prevent default pop
    } else {
      // Already at HomeScreen → double-tap exit
      final now = DateTime.now();
      if (_lastBackPressed == null ||
          now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
        _lastBackPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Press back again to exit the app')),
        );
        return false;
      }
      return true; // exit app
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: widget.child,
    );
  }
}