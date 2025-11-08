
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:universal_html/html.dart' as html;

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

  void _uploadCSV() {
    var uploadInput = html.FileUploadInputElement()..accept = '.csv';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final file = uploadInput.files?.first;
      if (file != null) {
        final reader = html.FileReader();
        reader.readAsText(file);
        reader.onLoadEnd.listen((event) async {
          final lines = const LineSplitter().convert(reader.result as String);
          final headers = lines.first.split(',');

          for (int i = 1; i < lines.length; i++) {
            final values = lines[i].split(',');
            final data = {
              for (int j = 0; j < headers.length && j < values.length; j++)
                headers[j].trim(): values[j].trim(),
            };

            final existing = await userCollection
                .where('Accession Number', isEqualTo: data['Accession Number'])
                .get();

            if (existing.docs.isEmpty) {
              await userCollection.add(data);
            }
          }

          _loadData();
        });
      }
    });
  }

  void _downloadTemplate() {
    const headers =
        "Crop,Accession Number,Name,Genus,Species,Origin,Donor Institute,Collection Date\n";
    final bytes = utf8.encode(headers);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "germplasm_template.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _exportCSV() {
    if (_entries.isEmpty) return;

    final headers = _fields.join(',') + '\n';
    final rows = _entries.map((e) => _fields.map((f) => e[f] ?? '').join(',')).join('\n');
    final csv = headers + rows;

    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "germplasm_entries.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _deleteEntry(String docId) async {
    await userCollection.doc(docId).delete();
    _loadData();
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
                  const Text(
                    'Add Germplasm Entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                              fillColor: Colors.green.shade50,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) => value!.isEmpty ? 'Required' : null,
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
const Text('Your Entries:', style: TextStyle(fontWeight: FontWeight.bold)),
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: DataTable(
    columns: [
      DataColumn(label: Text('Accession Number')),
      DataColumn(label: Text('Name')),
      DataColumn(label: Text('Crop')),
      DataColumn(label: Text('Genus')),
      DataColumn(label: Text('Species')),
      DataColumn(label: Text('Origin')),
      DataColumn(label: Text('Donor Institute')),
      DataColumn(label: Text('Collection Date')),
      DataColumn(label: Text('Delete')),
    ],
    rows: _entries.map((entry) {
      return DataRow(cells: [
        DataCell(Text(entry['Accession Number'] ?? '')),
        DataCell(Text(entry['Name'] ?? '')),
        DataCell(Text(entry['Crop'] ?? '')),
        DataCell(Text(entry['Genus'] ?? '')),
        DataCell(Text(entry['Species'] ?? '')),
        DataCell(Text(entry['Origin'] ?? '')),
        DataCell(Text(entry['Donor Institute'] ?? '')),
        DataCell(Text(entry['Collection Date'] ?? '')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteEntry(entry['id']),
          ),
        ),
      ]);
    }).toList(),
  ),
),

                ],
              ),
            ),
    );
  }
}
