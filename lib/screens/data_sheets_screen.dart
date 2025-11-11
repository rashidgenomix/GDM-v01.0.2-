import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:external_path/external_path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class DataSheetsScreen extends StatefulWidget {
  @override
  _DataSheetsScreenState createState() => _DataSheetsScreenState();
}

class _DataSheetsScreenState extends State<DataSheetsScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<String> experiments = [];
  String? selExp;

  List<String> accessions = [];
  String? selAcc;

  List<String> dates = [];
  String? selDate;

  List<Map<String, dynamic>> datasheet = [];
  bool loading = true, fetching = false;

  String get uid => _auth.currentUser!.uid;
  String? get email => _auth.currentUser!.email;

  String csvfile = "";

  @override
  void initState() {
    super.initState();
    _loadExperiments();
  }

  Future<void> _loadExperiments() async {
    final snap = await _fire
        .collection('users')
        .doc(uid)
        .collection('phenotyping_data')
        .get();

    experiments = snap.docs.map((d) => d.id).toList();
    setState(() => loading = false);
  }

  Future<void> _loadAccAndDates() async {
    if (selExp == null) return;
    final doc = await _fire
        .collection('users')
        .doc(uid)
        .collection('phenotyping_data')
        .doc(selExp)
        .get();

    final data = doc.data() ?? {};
    accessions = List<String>.from(data['accessions'] ?? []);
    dates = List<String>.from(data['dates'] ?? []);
    selAcc = selDate = null;
    datasheet.clear();
    setState(() {});
  }

  Future<void> _loadSheetRows() async {
    if (selExp == null || selAcc == null || selDate == null) return;
    setState(() => fetching = true);

    final snap = await _fire
        .collection('users')
        .doc(uid)
        .collection('phenotyping_data')
        .doc(selExp)
        .collection(selAcc!)
        .where('Date', isEqualTo: selDate)
        .get();

    datasheet = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    setState(() => fetching = false);
  }

  Future<File?> _makeCsv() async {
    try {
      final headers = datasheet.first.keys.toList();
      final rows = datasheet
          .map((r) => headers.map((h) => r[h]?.toString() ?? '').toList())
          .toList();
      final csv = const ListToCsvConverter().convert([headers, ...rows]);
      csvfile = csv;

      final String? saveOption = await _showSaveOptionsDialog();
      if (saveOption == null) return null;

      switch (saveOption) {
        case 'choose_location':
          return await _saveWithFilePicker(csv);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String?> _showSaveOptionsDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export CSV File'),
          content: const Text('Choose where to save:'),
          actions: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Choose Location'),
              subtitle: const Text('Select custom folder'),
              onTap: () => Navigator.pop(context, 'choose_location'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
  }

  Future<File?> _saveWithFilePicker(String csv) async {
    final safeExp = selExp?.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_') ?? 'unknown';
    final safeAcc = selAcc?.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_') ?? 'unknown';
    final safeDate = selDate?.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_') ?? 'unknown';

    final fileName = 'datasheet_${safeExp}_${safeAcc}_${safeDate}.csv';
    final bytes = Uint8List.fromList(csv.codeUnits);

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );

    if (outputPath == null) return null;

    final filePath = outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
    final file = File(filePath);
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File Saved at $filePath')),
    );
    return file;
  }

  Future<void> _exportCsv() async {
    if (datasheet.isEmpty) return;
    await _makeCsv();
  }

  Future<void> _emailCsv() async {
    final url = Uri.parse('https://ddsdp.uaar.edu.pk/PGB/receive_csv.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'csv': convertToCsv(datasheet),
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV sent to ${email}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send ${email}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send $e')),
      );
    }
  }

  String convertToCsv(List<Map<String, dynamic>> data) {
    List<List<dynamic>> rows = [];
    rows.add(data.first.keys.toList());
    for (var item in data) {
      rows.add(item.values.toList());
    }
    return const ListToCsvConverter().convert(rows);
  }

  @override
  Widget build(BuildContext ctx) {
    if (loading) return const Scaffold(
        body: Center(child: CircularProgressIndicator())
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Export Datasheet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Experiment Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Experiment'),
              items: experiments
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              value: selExp,
              onChanged: (e) {
                selExp = e;
                _loadAccAndDates();
              },
            ),
            const SizedBox(height: 16),

            // Accession Dropdown
            if (accessions.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Accession'),
                items: accessions
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                value: selAcc,
                onChanged: (a) {
                  selAcc = a;
                  datasheet.clear();
                  setState(() {});
                },
              ),
            if (accessions.isNotEmpty) const SizedBox(height: 16),

            // Date Dropdown
            if (dates.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Date'),
                items: dates
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                value: selDate,
                onChanged: (d) {
                  selDate = d;
                  _loadSheetRows();
                },
              ),
            if (dates.isNotEmpty) const SizedBox(height: 16),

            if (fetching)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),

            // CHANGED: Table + buttons layout
            if (!fetching && datasheet.isNotEmpty)
              Flexible(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: datasheet.first.keys
                                .map((k) => DataColumn(label: Text(k)))
                                .toList(),
                            rows: datasheet
                                .map((row) => DataRow(
                              cells: row.values
                                  .map((v) => DataCell(Text(v.toString())))
                                  .toList(),
                            ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.download),
                                label: const Text('Export CSV'),
                                onPressed: _exportCsv,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.email),
                                label: const Text('Email CSV'),
                                onPressed: _emailCsv,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!fetching && selDate != null && datasheet.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No data found for that date.'),
              ),
          ],
        ),
      ),
    );
  }
}
