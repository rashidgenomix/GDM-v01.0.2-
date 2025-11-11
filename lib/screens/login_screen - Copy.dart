import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? _error;





  void _login() async {
    print("login-click");


    final error = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );


print("error-check");
print(error);
 if(error!.length>0){
   print("login-error");
   print(error);
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('${error}')),
   );
 }else{
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Login Successfully')),
   );

   if (!mounted) return;

   Navigator.pushAndRemoveUntil(
     context,
     MaterialPageRoute(builder: (_) => HomeScreen()),
         (route) => false, // removes all previous routes
   );


 }

/*
    if (error != null) {
      setState(() => _error = error);
    } else {
      print("inside-else");
      if (!mounted) return;
      //Navigator.pop(context, true); // ✅ Return to Home after signup

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>  HomeScreen()),
      );
    }

    */
  }



  Future<void> _loginxcv() async {
      String message = '';
      if (true) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          Future.delayed(const Duration(seconds: 3), () {
            print('success');
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => HomeScreen(),
              ),
            );
          });
        } on FirebaseAuthException catch (e) {
          if (e.code == 'INVALID_LOGIN_CREDENTIALS') {
            message = 'Invalid login credentials.';
          } else {
            message = e.code;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${message}')),
          );
        }
      }


  }




  Future<void> _loginxxxxx() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
     // if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) =>  HomeScreen()),
      );
    } catch (e) {
      setState(() => _error = "Login failed. Check credentials.$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text("Login")),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: const Text("Don't have an account? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
