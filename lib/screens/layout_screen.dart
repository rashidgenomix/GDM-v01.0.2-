import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expNameController = TextEditingController();
  String _layoutType = 'RCBD';
  int _reps = 3;
  int _treatments = 4;
  int _observations = 2;

  List<Map<String, dynamic>> _savedLayouts = [];

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('experiment_layouts')
        .get();

    setState(() {
      _savedLayouts = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    });
  }

  Future<void> _saveLayout() async {
    if (!_formKey.currentState!.validate()) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('experiment_layouts')
        .doc(_expNameController.text.trim());

    await docRef.set({
      'design': _layoutType,
      'replications': _reps,
      'treatments': _treatments,
      'observations': _observations,
    });

    _expNameController.clear();
    _layoutType = 'RCBD';
    _reps = 3;
    _treatments = 4;
    _observations = 2;

    _loadLayouts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout saved successfully')),
    );
  }

  Future<String> _getDownloadPath() async {
    final dir = await getExternalStorageDirectory();
    final path = '${dir!.path}/Download';
    final directory = Directory(path);
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
    return path;
  }

  Future<void> _downloadCSVTemplate() async {
    const header = 'Experiment ID,Layout Type,Replications,Treatments,Observations\n';
    final path = await _getDownloadPath();
    final file = File('$path/layout_template.csv');
    await file.writeAsString(header);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template downloaded to ${file.path}')),
    );
  }

  Future<void> _exportCSV() async {
    if (_savedLayouts.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Experiment ID,Layout Type,Replications,Treatments,Observations');

    for (final layout in _savedLayouts) {
      buffer.writeln([
        layout['id'],
        layout['design'],
        layout['replications'],
        layout['treatments'],
        layout['observations'],
      ].join(','));
    }

    final path = await _getDownloadPath();
    final file = File('$path/saved_layouts.csv');
    await file.writeAsString(buffer.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Layouts exported as CSV in ${file.path}')),
    );
  }

  Future<void> _uploadCSV() async {
    final typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',');
      if (values.length < 5) continue;

      final layoutId = values[0].trim();
      final design = values[1].trim();
      final reps = int.tryParse(values[2].trim()) ?? 1;
      final trts = int.tryParse(values[3].trim()) ?? 1;
      final obs = int.tryParse(values[4].trim()) ?? 1;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('experiment_layouts')
          .doc(layoutId);

      await docRef.set({
        'design': design,
        'replications': reps,
        'treatments': trts,
        'observations': obs,
      });
    }

    _loadLayouts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("CSV uploaded successfully")),
    );
  }

  Future<void> _deleteLayout(String layoutId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('experiment_layouts')
        .doc(layoutId)
        .delete();

    _loadLayouts();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Experiment Layout'),
          backgroundColor: Colors.teal,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text('Define New Layout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _expNameController,
                      decoration: const InputDecoration(labelText: 'Experiment Name / ID'),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _layoutType,
                      decoration: const InputDecoration(labelText: 'Layout Type'),
                      items: ['RCBD', 'CRD', 'FACTORIAL', 'AUGMENTED'].map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) => setState(() => _layoutType = value!),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_reps',
                            decoration: const InputDecoration(labelText: 'Replications'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _reps = int.tryParse(val) ?? 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_treatments',
                            decoration: const InputDecoration(labelText: 'Treatments'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _treatments = int.tryParse(val) ?? 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: '$_observations',
                            decoration: const InputDecoration(labelText: 'Observations'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _observations = int.tryParse(val) ?? 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveLayout,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Layout'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _downloadCSVTemplate,
                      icon: const Icon(Icons.download),
                      label: const Text('Download CSV Template'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _uploadCSV,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Layouts CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportCSV,
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export Layouts CSV'),
                    ),
                    const Divider(height: 40),
                  ],
                ),
              ),
              const Text('Saved Layouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _savedLayouts.isEmpty
                  ? const Text('No layouts added yet.')
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Design')),
                          DataColumn(label: Text('Reps')),
                          DataColumn(label: Text('Trt')),
                          DataColumn(label: Text('Obs')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _savedLayouts.map((layout) {
                          return DataRow(
                            cells: [
                              DataCell(Text(layout['id'])),
                              DataCell(Text(layout['design'])),
                              DataCell(Text('${layout['replications']}')),
                              DataCell(Text('${layout['treatments']}')),
                              DataCell(Text('${layout['observations']}')),
                              DataCell(IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteLayout(layout['id']),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
