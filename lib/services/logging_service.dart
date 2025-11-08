import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoggingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> logAction({
    required String action,
    required String details,
  }) async {
    if (uid == null) return;

    final logRef = _db.collection("users").doc(uid).collection("logs").doc();

    await logRef.set({
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
      'uid': uid,
    });
  }
}
