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
  String?  selExp;

  List<String> accessions = [];
  String?  selAcc;

  List<String> dates = [];
  String?  selDate;

  List<Map<String,dynamic>> datasheet = [];
  bool loading = true, fetching = false;

  String get uid => _auth.currentUser!.uid;
  String? get email=> _auth.currentUser!.email;
  //String? get email=> "asimmehmood247@gmail.com";

  String csvfile="";




  @override
  void initState() {
    super.initState();
    _loadExperiments();
  }

  Future<void> _loadExperiments() async {
    final snap = await _fire
        .collection('users').doc(uid)
        .collection('phenotyping_data')
        .get();

    experiments = snap.docs.map((d) => d.id).toList();
    setState(() => loading = false);
  }

  Future<void> _loadAccAndDates() async {
    if (selExp == null) return;
    final doc = await _fire
        .collection('users').doc(uid)
        .collection('phenotyping_data')
        .doc(selExp)
        .get();

    final data = doc.data() ?? {};
    accessions = List<String>.from(data['accessions'] ?? []);
    dates      = List<String>.from(data['dates']      ?? []);
    // clear any old selections
    selAcc = selDate = null;
    datasheet.clear();

    setState(() {});
  }

  Future<void> _loadSheetRows() async {
    if (selExp==null || selAcc==null || selDate==null) return;
    setState(() => fetching = true);

    final snap = await _fire
        .collection('users').doc(uid)
        .collection('phenotyping_data')
        .doc(selExp)
        .collection(selAcc!)
        .where('Date', isEqualTo: selDate)
        .get();

    datasheet = snap.docs.map((d) {
      return {'id': d.id, ...d.data()};
    }).toList();

    setState(() => fetching = false);
  }

  Future<File> _makeCsvxx() async {
    // 1. Request Storage Permissions (for older Android versions especially)
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission not granted. Cannot save file.');
      }
    }

    // Convert datasheet to CSV
    final headers = datasheet.first.keys.toList();
    final rows = datasheet
        .map((r) => headers.map((h) => r[h]?.toString() ?? '').toList())
        .toList();
    final csvContent = const ListToCsvConverter().convert([headers, ...rows]);
    // csvfile = csvContent; // This line seems to be assigning to a global/class variable. Keep if needed.

    // Convert the CSV string to bytes (Uint8List)
    final Uint8List csvBytes = Uint8List.fromList(csvContent.codeUnits);

    // 2. Ask user to pick a save location and provide the bytes directly
    final String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV File',
      fileName: 'export_${selExp}_$selAcc\_$selDate.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: csvBytes, // <--- THIS IS THE CRUCIAL CHANGE
    );

    print("outputpath");
    print(outputPath);

    if (outputPath == null) {
      throw Exception('User canceled file save dialog');
    }

    // FilePicker.platform.saveFile() with bytes already saves the file.
    // We just need to return a File object representing the saved file.
    final file = File(outputPath);

    // You no longer need `await file.writeAsString(csv);` here
    // because `FilePicker` handles the writing when `bytes` are provided.

    print('CSV file saved successfully to: $outputPath');
    return file;
  }


  Future<File> _makeCsvlast() async {
    // Convert datasheet to CSV
    final headers = datasheet.first.keys.toList();
    final rows = datasheet
        .map((r) => headers.map((h) => r[h]?.toString() ?? '').toList())
        .toList();
    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    csvfile = csv;

    // Request storage permission
    final hasStoragePermission = await Permission.storage.request().isGranted;

    // For Android 11+ also check MANAGE_EXTERNAL_STORAGE
    final hasManageStorage = await Permission.manageExternalStorage.isGranted;

    if (!hasStoragePermission && !hasManageStorage) {
      throw Exception('Storage permission not granted');
    }


    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/datasheet_export_${selExp}_$selAcc\_$selDate.csv');
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to: ${file.path}')),
    );

    return file;
  }


  // Add these methods to your existing _DataSheetsScreenState class:

  Future<File?> _makeCsv() async {
    try {
      // Your existing CSV generation code
      final headers = datasheet.first.keys.toList();
      final rows = datasheet
          .map((r) => headers.map((h) => r[h]?.toString() ?? '').toList())
          .toList();
      final csv = const ListToCsvConverter().convert([headers, ...rows]);
      csvfile = csv;

      // Show save options
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


    // Convert string to bytes
    final bytes = Uint8List.fromList(csv.codeUnits);

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes, // Add the bytes parameter
    );
 print("file-path");
 print(outputPath);
    if (outputPath == null) return null;

    final filePath = outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
    final file = File(filePath);
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File Saved at $filePath')),
    );
    return file;
  }

  Future<File?> _saveWithFilePickerxxx(String csv) async {
    final fileName = 'datasheet_${selExp}_${selAcc}_${selDate}.csv';

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputPath == null) return null;

    final filePath = outputPath.endsWith('.csv') ? outputPath : '$outputPath.csv';
    final file = File(filePath);
    await file.writeAsString(csv);
    return file;
  }

  Future<File?> _saveToDownloads(String csv) async {
    try {
      final directory = await getExternalStorageDirectory();
      final downloadsPath = '${directory!.path}/Download';
      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName = 'datasheet_${selExp}_${selAcc}_${selDate}.csv';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsString(csv);
      return file;
    } catch (e) {
      print(e.toString());
      // Fallback to file picker
      return await _saveWithFilePicker(csv);
    }
  }

  Future<File?> _saveToDocuments(String csv) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'datasheet_${selExp}_${selAcc}_${selDate}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);
    return file;
  }



  Future<void> _exportCsv() async {


    if (datasheet.isEmpty) return;
    final file = await _makeCsv();

/*

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exported to ${file.path}')),
    );
*/

  }


  Future<void> _emailCsvddd() async {
    if (datasheet.isEmpty) return;
    final file = await _makeCsv();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV sent to ${email}')),
    );


  }


  String convertToCsv(List<Map<String, dynamic>> data) {
    List<List<dynamic>> rows = [];

    // Add headers
    rows.add(data.first.keys.toList());

    // Add data rows
    for (var item in data) {
      rows.add(item.values.toList());
    }

    return const ListToCsvConverter().convert(rows);
  }



  Future<void> _emailCsv() async {
   // final file = await _makeCsv();
    final url = Uri.parse('https://ddsdp.uaar.edu.pk/PGB/receive_csv.php'); // Replace with your PHP endpoint

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
        print('✅ CSV sent successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV sent to ${email}')),
        );
      } else {
        print('❌ Failed to send CSV: ${response.statusCode}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send ${email}')),
        );
      }


        ();


    } catch (e) {
      print('⚠️ Error sending CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send $e')),
      );

    }
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
            // 1) pick experiment
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

            // 2) pick accession
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

            // 3) pick date
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

            // spinner while loading rows
            if (fetching)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),

            // table preview + export
            if (!fetching && datasheet.isNotEmpty) ...[
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
              const SizedBox(height: 16),
            ],

            // Buttons section - Made responsive
            if (!fetching && datasheet.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  // For small screens, use column layout for buttons
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('Export CSV'),
                            onPressed: _exportCsv,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.email),
                            label: const Text('Email CSV'),
                            onPressed: _emailCsv,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // For larger screens, use row layout
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                          onPressed: _exportCsv,
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.email),
                          label: const Text('Email CSV'),
                          onPressed: _emailCsv,
                        ),
                      ],
                    );
                  }
                },
              ),

            // No data message
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




