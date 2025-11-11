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

/// Global back handler to manage back button behavior across the app
class GlobalBackHandler extends StatefulWidget {
  final Widget child;
  const GlobalBackHandler({super.key, required this.child});

  @override
  State<GlobalBackHandler> createState() => _GlobalBackHandlerState();
}

class _GlobalBackHandlerState extends State<GlobalBackHandler> {
  DateTime? _lastBackPressed;

  Future<bool> _onWillPop() async {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      // Subscreen → exit to home dialog
      final exit = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Exit to Home'),
              content: const Text('Are you sure you want to go back to Home?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          ) ??
          false;

      if (exit) navigator.pop();
      return false; // prevent default pop
    } else {
      // Home → double-tap exit
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