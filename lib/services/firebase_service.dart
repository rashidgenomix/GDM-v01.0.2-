import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/germplasm_entry.dart';

class FirebaseService {
  final CollectionReference entries =
      FirebaseFirestore.instance.collection('germplasm_entries');

  Future<void> addEntry(GermplasmEntry entry) async {
    await entries.doc(entry.id).set(entry.toMap());
  }

  Future<void> deleteEntry(String id) async {
    await entries.doc(id).delete();
  }

  Future<void> updateEntry(GermplasmEntry entry) async {
    await entries.doc(entry.id).update(entry.toMap());
  }

  Stream<List<GermplasmEntry>> getAllEntries() {
    return entries.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => GermplasmEntry.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }
}
