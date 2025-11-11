import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to listen for auth state changes
  Stream<User?> get userChanges => _auth.authStateChanges();

  // Current user getter
  User? get currentUser => _auth.currentUser;



  // Sign up
  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Sign in
  Future<String?> signIn(String email, String password) async {
    try {
      print("auth-services");
      final error = await _auth.signInWithEmailAndPassword(email: email, password: password);
      print("auth-error");
      print(error);
      return error.toString();
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check login status
  bool get isLoggedIn => _auth.currentUser != null;
}
