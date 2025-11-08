import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class DescriptorScreen extends StatefulWidget {
  const DescriptorScreen({super.key});

  @override
  State<DescriptorScreen> createState() => _DescriptorScreenState();
}

class _DescriptorScreenState extends State<DescriptorScreen> {
  final _cropController = TextEditingController();
  final _scientificNameController = TextEditingController();
  final _traitController = TextEditingController();
  List<String> _traits = [];
  bool _isUploading = false;
  Map<String, Map<String, dynamic>> _uploadedDescriptors = {};

  @override
  void initState() {
    super.initState();
    _fetchUploadedDescriptors();
  }

  Future<void> _fetchUploadedDescriptors() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('descriptors')
        .get();

    final descriptors = {
      for (var doc in snapshot.docs) doc.id: doc.data(),
    };

    setState(() => _uploadedDescriptors = descriptors);
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

  Future<void> _saveDescriptor() async {
    if (_cropController.text.isEmpty || _traits.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('descriptors')
        .doc(_cropController.text.trim());

    await docRef.set({
      'crop': _cropController.text.trim(),
      'scientificName': _scientificNameController.text.trim(),
      'traits': _traits,
    });

    _cropController.clear();
    _scientificNameController.clear();
    _traitController.clear();
    _traits.clear();
    _fetchUploadedDescriptors();
  }

  Future<void> _downloadCSVTemplate() async {
    const header = 'Crop,Scientific Name,Trait 1,Trait 2,Trait 3\n';
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/descriptor_template.csv');
      await file.writeAsString(header);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template downloaded to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save template: $e')),
      );
    }
  }

  Future<void> _uploadCSV() async {
    final typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) return;

    setState(() => _isUploading = true);
    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);

    for (var i = 1; i < lines.length; i++) {
      final values = lines[i].split(',');
      if (values.length >= 3) {
        final crop = values[0].trim();
        final scientificName = values[1].trim();
        final traits = values.sublist(2).where((t) => t.trim().isNotEmpty).toList();

        final uid = FirebaseAuth.instance.currentUser!.uid;
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('descriptors')
            .doc(crop);

        await docRef.set({
          'crop': crop,
          'scientificName': scientificName,
          'traits': traits,
        });
      }
    }

    setState(() => _isUploading = false);
    _fetchUploadedDescriptors();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.deepPurple,
            title: const Text('Descriptor Manager'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Add Descriptor'),
                Tab(text: 'Uploaded Descriptors'),
              ],
              indicatorColor: Colors.white,
            ),
          ),
          body: TabBarView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _cropController,
                        decoration: const InputDecoration(labelText: 'Crop Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _scientificNameController,
                        decoration: const InputDecoration(labelText: 'Scientific Name'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _traitController,
                              decoration: const InputDecoration(labelText: 'Add Trait'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addTrait,
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _traits.map((t) => Chip(label: Text(t))).toList(),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _saveDescriptor,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Descriptor'),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _downloadCSVTemplate,
                        icon: const Icon(Icons.download),
                        label: const Text('Download Template'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _uploadCSV,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload CSV'),
                      ),
                      if (_isUploading)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _uploadedDescriptors.isEmpty
                    ? const Center(child: Text('No descriptors uploaded yet.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Crop')),
                            DataColumn(label: Text('Scientific Name')),
                            DataColumn(label: Text('Traits')),
                          ],
                          rows: _uploadedDescriptors.entries.map((entry) {
                            final data = entry.value;
                            final traits = (data['traits'] as List).join(', ');
                            return DataRow(cells: [
                              DataCell(Text(data['crop'] ?? '-')),
                              DataCell(Text(data['scientificName'] ?? '-')),
                              DataCell(Text(traits)),
                            ]);
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
