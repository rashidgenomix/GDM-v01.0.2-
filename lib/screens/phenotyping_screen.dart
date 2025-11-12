import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class PhenotypingScreen extends StatefulWidget {
  final String? qrAccession;

  const PhenotypingScreen({super.key, this.qrAccession});

  @override
  State<PhenotypingScreen> createState() => _PhenotypingScreenState();
}

class _PhenotypingScreenState extends State<PhenotypingScreen> {
  String? selectedAccession;
  String? selectedExperiment;
  DateTime selectedDate = DateTime.now();
  bool showGrid = false;
  bool isLoading = true;

  List<Map<String, dynamic>> datasheetRows = [];
  List<String> germplasmList = [];
  List<String> experimentList = [];
  List<String> traits = [];

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _fetchGermplasm();
    _fetchExperiments();
  }

  // ----------------------------
  // Minimal changes: Save CSV
  // ----------------------------
  Future<void> _exportCSV() async {
    if (datasheetRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No data to export.")));
      return;
    }

    final headers = [
      'Rep',
      'Trt',
      'Obs',
      'Accession',
      'Experiment',
      ...traits
    ];

    final rows = datasheetRows.map((row) {
      return headers.map((h) {
        final val = (row[h] ?? '').toString();
        return '"${val.replaceAll('"', '""')}"';
      }).join(',');
    }).join('\n');

    final csvContent = headers.join(',') + '\n' + rows;

    try {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));

      final String fileName = 'phenotyping_${selectedExperiment ?? "data"}_${selectedAccession ?? "all"}.csv';

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Save cancelled")));
        return;
      }

      final path = outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File saved at $path")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save CSV: $e")));
    }
  }
  // ----------------------------
  // End Save CSV
  // ----------------------------

  Future<void> handleQRScan(String qrCode) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('germplasm_entries')
        .doc(qrCode)
        .get();

    if (doc.exists) {
      final accession = doc['Accession Number']?.toString();

      if (accession != null && germplasmList.contains(accession)) {
        setState(() {
          selectedAccession = accession;
        });
      } else {
        print('⚠️ Accession not in dropdown list: $accession');
      }
    } else {
      print('❌ No document found for QR: $qrCode');
    }
  }

  Future<void> _fetchGermplasm() async {
    try {
      if (widget.qrAccession == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(" QR accession is null")));
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('germplasm_entries')
          .doc(widget.qrAccession)
          .get();

      if (doc.exists) {
        final accession = doc['Accession Number']?.toString();
        if (accession != null && accession.isNotEmpty) {
          setState(() {
            germplasmList = [accession];
            selectedAccession = accession;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching germplasm: $e');
    }
  }

  Future<void> _fetchExperiments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experiments')
        .get();
    setState(() {
      experimentList = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Future<void> _generateDataSheet() async {
    if (selectedAccession == null || selectedExperiment == null) return;

    final expDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experiments')
        .doc(selectedExperiment)
        .get();

    final layout = {
      'replications': expDoc['replications'],
      'treatments': expDoc['treatments'],
      'observations': expDoc['observations'],
    };

    traits = List<String>.from(expDoc['traits'] ?? []);
    datasheetRows = [];

    for (int rep = 1; rep <= (layout['replications'] ?? 0); rep++) {
      for (int trt = 1; trt <= (layout['treatments'] ?? 0); trt++) {
        for (int obs = 1; obs <= (layout['observations'] ?? 0); obs++) {
          final row = {
            'Rep': rep,
            'Trt': trt,
            'Obs': obs,
            'Accession': selectedAccession,
            'Experiment': selectedExperiment,
            for (var trait in traits) trait: '',
          };
          datasheetRows.add(row);
        }
      }
    }

    setState(() {
      showGrid = true;
    });
  }

  Future<void> _saveData() async {
    final root = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('phenotyping_data')
        .doc(selectedExperiment);

    final subcol = root.collection(selectedAccession!);
    final batch = FirebaseFirestore.instance.batch();

    for (var row in datasheetRows) {
      final id = "${row['Rep']}_${row['Trt']}_${row['Obs']}";
      batch.set(subcol.doc(id), {
        'Experiment': selectedExperiment,
        'Accession': row['Accession'],
        'Date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'Rep': row['Rep'],
        'Trt': row['Trt'],
        'Obs': row['Obs'],
        for (var trait in traits) trait: row[trait],
      });
    }

    batch.set(root, {
      'accessions': FieldValue.arrayUnion([selectedAccession]),
      'dates': FieldValue.arrayUnion([DateFormat('yyyy-MM-dd').format(selectedDate)]),
    }, SetOptions(merge: true));

    await batch.commit();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Phenotyping data saved.")));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Phenotyping"),
          actions: [
            if (showGrid)
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportCSV, // <-- new download button
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: selectedAccession,
                      decoration:
                          const InputDecoration(labelText: 'Select Accession'),
                      items: germplasmList.map((e) {
                        return DropdownMenuItem(value: e, child: Text(e));
                      }).toList(),
                      onChanged: (val) {
                        setState(() => selectedAccession = val);
                      },
                    ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedExperiment,
                decoration:
                    const InputDecoration(labelText: 'Select Experiment'),
                items: experimentList.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e));
                }).toList(),
                onChanged: (val) {
                  setState(() => selectedExperiment = val);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _generateDataSheet,
                child: const Text("Start Recording"),
              ),
              const SizedBox(height: 20),
              if (showGrid)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Rep')),
                      const DataColumn(label: Text('Trt')),
                      const DataColumn(label: Text('Obs')),
                      const DataColumn(label: Text('Accession')),
                      const DataColumn(label: Text('Experiment')),
                      ...traits.map((t) => DataColumn(label: Text(t))),
                    ],
                    rows: datasheetRows.map((row) {
                      return DataRow(cells: [
                        DataCell(Text('${row['Rep']}')),
                        DataCell(Text('${row['Trt']}')),
                        DataCell(Text('${row['Obs']}')),
                        DataCell(Text('${row['Accession']}')),
                        DataCell(Text('${row['Experiment']}')),
                        ...traits.map((t) {
                          return DataCell(
                            TextFormField(
                              initialValue: row[t],
                              onChanged: (val) => row[t] = val,
                              decoration: const InputDecoration(
                                  border: InputBorder.none),
                            ),
                          );
                        }),
                      ]);
                    }).toList(),
                  ),
                ),
              if (showGrid)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    onPressed: _saveData,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Data"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
