import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _error;

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required.')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await _authService.signUp(email, password);

      if (!mounted) return;

      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup successful! Please verify your email.')),
        );

        await Future.delayed(const Duration(milliseconds: 1000));

        if (!mounted) return;

        // Redirect to HomeScreen (optional) or Login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - kToolbarHeight - 40,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.05),

                    // Email field
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Password"),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password field
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(labelText: "Confirm Password"),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),

                    // Signup button or loader
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _signup,
                              child: const Text("Sign Up"),
                            ),
                          ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],

                    const SizedBox(height: 20),

                    // Back to login
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text("Already have an account? Login"),
                    ),

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
