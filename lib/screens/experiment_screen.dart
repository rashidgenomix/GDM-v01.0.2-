import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';

class ExperimentScreen extends StatefulWidget {
  const ExperimentScreen({super.key});

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen> {
  final _expNameController = TextEditingController();
  final _traitController = TextEditingController();
  String _layoutType = 'RCBD';
  int _reps = 3;
  int _treatments = 4;
  int _observations = 2;
  List<String> _traits = [];
  List<Map<String, dynamic>> _savedExperiments = [];

  @override
  void initState() {
    super.initState();
    _loadExperiments();
  }

  Future<void> _loadExperiments() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experiments')
        .get();

    setState(() {
      _savedExperiments = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  void _addTrait() {
    final trait = _traitController.text.trim();
    if (trait.isNotEmpty && !_traits.contains(trait)) {
      setState(() {
        _traits.add(trait);
        _traitController.clear();
      });
    }
  }

  Future<void> _saveExperiment() async {
    if (_expNameController.text.isEmpty || _traits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Experiment ID and add Traits')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experiments')
        .doc(_expNameController.text.trim());

    await docRef.set({
      'experiment_id': _expNameController.text.trim(),
      'layout_type': _layoutType,
      'replications': _reps,
      'treatments': _treatments,
      'observations': _observations,
      'traits': _traits,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Experiment saved successfully')),
    );

    _expNameController.clear();
    _traitController.clear();
    _traits.clear();
    _reps = 3;
    _treatments = 4;
    _observations = 2;
    _layoutType = 'RCBD';
    setState(() {});
    _loadExperiments();
  }

  // ----------------- Download Template -----------------
  Future<void> _downloadTemplate() async {
    final header = 'Experiment ID,Layout Type,Replications,Treatments,Observations,Trait1,Trait2,Trait3\n';
    final bytes = Uint8List.fromList(utf8.encode(header));

    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Experiment Template',
        fileName: 'experiment_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (path != null) {
        final file = File(path.endsWith('.csv') ? path : '$path.csv');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template saved at: ${file.path}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template save cancelled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save template: $e')),
      );
    }
  }

  // ----------------- Upload CSV -----------------
  Future<void> _uploadCSV() async {
    final typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',');
      if (values.length < 5) continue;

      final expId = values[0].trim();
      final layoutType = values[1].trim();
      final reps = int.tryParse(values[2].trim()) ?? 1;
      final treatments = int.tryParse(values[3].trim()) ?? 1;
      final observations = int.tryParse(values[4].trim()) ?? 1;
      final traits = values.sublist(5).where((t) => t.trim().isNotEmpty).toList();

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('experiments')
          .doc(expId);

      await docRef.set({
        'experiment_id': expId,
        'layout_type': layoutType,
        'replications': reps,
        'treatments': treatments,
        'observations': observations,
        'traits': traits,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV uploaded successfully')),
    );
    _loadExperiments();
  }

  // ----------------- Export CSV -----------------
  Future<void> _exportCSV() async {
    if (_savedExperiments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No experiments to export')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Experiment ID,Layout Type,Replications,Treatments,Observations,Traits');

    for (final exp in _savedExperiments) {
      final traits = (exp['traits'] as List).join(';');
      buffer.writeln([
        exp['experiment_id'],
        exp['layout_type'],
        exp['replications'],
        exp['treatments'],
        exp['observations'],
        traits,
      ].join(','));
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));

    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Experiments CSV',
        fileName: 'saved_experiments_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (path != null) {
        final file = File(path.endsWith('.csv') ? path : '$path.csv');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Experiments exported successfully: ${file.path}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Experiment Setup'),
          backgroundColor: Colors.teal,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Define New Experiment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _expNameController,
                decoration: const InputDecoration(labelText: 'Experiment ID'),
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
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Replications'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _reps = int.tryParse(val) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Treatments'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _treatments = int.tryParse(val) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Observations'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _observations = int.tryParse(val) ?? 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _traitController,
                      decoration: const InputDecoration(labelText: 'Add Trait'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addTrait,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _traits.map((t) => Chip(label: Text(t))).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saveExperiment,
                icon: const Icon(Icons.save),
                label: const Text('Save Experiment'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download),
                label: const Text('Download Template'),
              ),
              OutlinedButton.icon(
                onPressed: _uploadCSV,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload from CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _exportCSV,
                icon: const Icon(Icons.file_download),
                label: const Text('Export Experiments CSV'),
              ),
              const Divider(height: 30),
              const Text('Saved Experiments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _savedExperiments.isEmpty
                  ? const Text('No experiments added yet.')
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Design')),
                          DataColumn(label: Text('Traits')),
                        ],
                        rows: _savedExperiments.map((exp) {
                          final traits = (exp['traits'] as List).join(', ');
                          return DataRow(cells: [
                            DataCell(Text(exp['experiment_id'] ?? '-')),
                            DataCell(Text(exp['layout_type'] ?? '-')),
                            DataCell(Text(traits)),
                          ]);
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
