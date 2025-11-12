import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
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

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
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
      debugPrint("Error loading data: $e");
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

  // ===========================
  // ✅ CHANGE START: Upload CSV
  // Uses file_selector to open file, validates headers and imports rows
  // ===========================
  Future<void> _uploadCSV() async {
    final typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) return;

    try {
      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);
      if (lines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty')),
        );
        return;
      }

      final headers = lines.first.split(',').map((h) => h.trim()).toList();

      // Validate headers against template fields
      final missing = _fields.where((f) => !headers.contains(f)).toList();
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid CSV: Missing headers ${missing.join(", ")}')),
        );
        return;
      }

      // Parse and upload rows (non-destructive)
      int added = 0;
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
          added++;
        }
      }

      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV imported successfully. Added $added rows.')),
      );
    } catch (e) {
      debugPrint('Upload CSV failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload CSV: $e')),
      );
    }
  }
  // ===========================
  // ✅ CHANGE END Upload CSV
  // ===========================

  // ===========================
  // ✅ CHANGE START: Save logic (uses FilePicker save dialog)
  // Replaces previous getExternalStorageDirectory() behaviour
  // ===========================
  Future<void> _saveCSV(String fileName, String content) async {
    try {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(content));

      // Ask user where to save the file
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $fileName',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputPath == null) {
        // User cancelled
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled')),
        );
        return;
      }

      // Some implementations of saveFile already write bytes; writing again is safe.
      final path = outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
      final out = File(path);
      await out.writeAsBytes(bytes, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved: $path')),
      );
    } catch (e) {
      debugPrint('Save CSV error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save file: $e')),
      );
    }
  }
  // ===========================
  // ✅ CHANGE END Save logic
  // ===========================

  // ===========================
  // ✅ CHANGE START: Download template using _saveCSV
  // ===========================
  Future<void> _downloadTemplate() async {
    const headers =
        "Crop,Accession Number,Name,Genus,Species,Origin,Donor Institute,Collection Date\n";
    await _saveCSV("germplasm_template.csv", headers);
  }
  // ===========================
  // ✅ CHANGE END: Download template
  // ===========================

  // ===========================
  // ✅ CHANGE START: Export entries using _saveCSV
  // ===========================
  Future<void> _exportCSV() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export')),
      );
      return;
    }

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
  // ===========================
  // ✅ CHANGE END: Export entries
  // ===========================

  Future<void> _deleteEntry(String docId) async {
    debugPrint("Attempting to delete document with ID: $docId");

    try {
      await userCollection.doc(docId).delete();
      debugPrint("✅ Document deleted successfully.");
      await _loadData();
    } catch (e) {
      debugPrint("❌ Failed to delete document: $e");
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
