import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:germplasmx/screens/home_screen.dart';
import 'package:germplasmx/screens/login_screen.dart';
import 'package:germplasmx/screens/signup_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth/auth_provider.dart';

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
    return ScreenUtilInit(
      designSize: const Size(390, 844), // ✅ Responsive baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // ✅ CHANGE START — wrap entire MaterialApp with GlobalBackHandler
        return GlobalBackHandler(
          child: MaterialApp(
            title: 'Germplasm Data Manager',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.green,
              scaffoldBackgroundColor: Colors.white,
              useMaterial3: true,
            ),
            home: const HomeScreen(), // ✅ Home still default
          ),
        );
        // ✅ CHANGE END
      },
    );
  }
}

/// ✅ CHANGE START — Global handler now applies to *all* app screens
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
    final canPop = navigator.canPop();

    if (canPop) {
      // If not on home → go to HomeScreen instead of exiting
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return false;
    } else {
      // If on home → require double-tap to exit
      final now = DateTime.now();
      if (_lastBackPressed == null ||
          now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
        _lastBackPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Press back again to exit the app')),
        );
        return false;
      }
      return true; // Exit the app
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
/// ✅ CHANGE END
