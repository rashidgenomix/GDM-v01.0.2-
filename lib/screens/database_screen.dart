import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _fields = [
    'Crop',
    'Accession Number',
    'Name',
    'Genus',
    'Species',
    'Origin',
    'Donor Institute',
    'Collection Date',
  ];

  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    for (var field in _fields) {
      _controllers[field] = TextEditingController();
    }
    _loadData();
  }

  CollectionReference<Map<String, dynamic>> get userCollection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('germplasm_entries');

  Future<void> _loadData() async {
    try {
      final snapshot = await userCollection.get();
      setState(() {
        _entries = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      for (var field in _fields) field: _controllers[field]!.text.trim(),
    };

    final existing = await userCollection
        .where('Accession Number', isEqualTo: data['Accession Number'])
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duplicate entry!")),
      );
      return;
    }

    await userCollection.add(data);
    _clearForm();
    _loadData();
  }

  void _clearForm() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
  }

  Future<void> _uploadCSV() async {
    final typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      final content = await file.readAsString();

      print("content");
      print(content);
      final lines = const LineSplitter().convert(content);

      final headers = lines.first.split(',').map((h) => h.trim()).toList();

      for (int i = 1; i < lines.length; i++) {
        final values = lines[i].split(',');
        if (values.length != headers.length) continue;

        final data = {
          for (int j = 0; j < headers.length; j++)
            headers[j]: values[j].trim().replaceAll(RegExp(r'"'), ''),
        };

        final existing = await userCollection
            .where('Accession Number', isEqualTo: data['Accession Number'])
            .get();

        if (existing.docs.isEmpty) {
          await userCollection.add(data);
        }
      }

      _loadData();
    }
  }

  Future<void> _saveCSV(String fileName, String content) async {
    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/$fileName');
    await file.writeAsString(content);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to: ${file.path}')),
    );
  }

  Future<void> _downloadTemplate() async {
    const headers =
        "Crop,Accession Number,Name,Genus,Species,Origin,Donor Institute,Collection Date\n";
    await _saveCSV("germplasm_template.csv", headers);
  }

  Future<void> _exportCSV() async {
    if (_entries.isEmpty) return;

    final headers = _fields.join(',') + '\n';
    final rows = _entries.map((e) {
      return _fields.map((f) {
        final val = (e[f] ?? '').toString();
        return '"${val.replaceAll('"', '""')}"';
      }).join(',');
    }).join('\n');

    final csv = headers + rows;
    await _saveCSV("germplasm_entries.csv", csv);
  }

  Future<void> _deleteEntry(String docId) async {
    print("Attempting to delete document with ID: $docId");

    try {
      await userCollection.doc(docId).delete();


      print("✅ Document deleted successfully.");

      // Reload data after deletion
      await _loadData();
    } catch (e) {
      print("❌ Failed to delete document: $e");

      // Optionally show a message to the user
      // e.g. using a snackbar or dialog in your app
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Germplasm Database')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Add Germplasm Entry',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: _fields.map((field) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: TextFormField(
                            controller: _controllers[field],
                            decoration: InputDecoration(
                              labelText: '$field *',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Required' : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveEntry,
                        icon: const Icon(Icons.save),
                        label: const Text("Save Entry"),
                      ),
                      OutlinedButton.icon(
                        onPressed: _clearForm,
                        icon: const Icon(Icons.clear),
                        label: const Text("Clear"),
                      ),
                      OutlinedButton.icon(
                        onPressed: _uploadCSV,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Upload CSV"),
                      ),
                      OutlinedButton.icon(
                        onPressed: _downloadTemplate,
                        icon: const Icon(Icons.download),
                        label: const Text("Download Template"),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exportCSV,
                        icon: const Icon(Icons.file_download),
                        label: const Text("Export Entries"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Your Entries:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: _fields
                          .map((field) => DataColumn(label: Text(field)))
                          .toList()
                        ..add(const DataColumn(label: Text('Delete'))),
                      rows: _entries.map((entry) {
                        return DataRow(
                          cells: [
                            ..._fields
                                .map((field) =>
                                    DataCell(Text(entry[field] ?? '')))
                                .toList(),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEntry(entry['id']),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
