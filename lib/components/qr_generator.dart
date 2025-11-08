
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  String? _selectedEntryId;
  List<Map<String, dynamic>> _entries = [];
  List<String> _selectedIds = [];
  bool _selectAll = false;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('germplasm_entries')
        .get();

    setState(() {
      _entries = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }

  Future<void> _generatePdf(List<Map<String, dynamic>> entries) async {
    final pdf = pw.Document();
    for (var entry in entries) {
      final id = entry['id'] ?? '';
      final name = entry['Name'] ?? '';
      final crop = entry['Crop'] ?? '';
      final genus = entry['Genus'] ?? '';
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.BarcodeWidget(
                data: id,
                barcode: pw.Barcode.qrCode(),
                width: 150,
                height: 150,
              ),
              pw.SizedBox(height: 10),
              pw.Text("Name: $name"),
              pw.Text("Crop: $crop"),
              pw.Text("Genus: $genus"),
            ],
          ),
        ),
      );
    }

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  List<Map<String, dynamic>> get _pagedEntries {
    final start = _currentPage * _rowsPerPage;
    return _entries.skip(start).take(_rowsPerPage).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Generator')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          DropdownButton<String>(
            hint: const Text("Select Entry for Single QR"),
            value: _selectedEntryId,
            isExpanded: true,
            items: _entries
                .map((entry) => DropdownMenuItem<String>(
                      value: entry['id'],
                      child: Text(entry['Name'] ?? ''),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedEntryId = value),
          ),
          ElevatedButton(
            onPressed: () {
              final entry = _entries.firstWhere(
                  (element) => element['id'] == _selectedEntryId,
                  orElse: () => {});
              if (entry.isNotEmpty) {
                _generatePdf([entry]);
              }
            },
            child: const Text("Download Single QR as PDF"),
          ),
          const Divider(),
          ElevatedButton(
            onPressed: () {
              final selectedEntries = _entries
                  .where((e) => _selectedIds.contains(e['id']))
                  .toList();
              _generatePdf(selectedEntries);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text("Download Selected QRs (PDF)"),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: (value) {
                  setState(() {
                    _selectAll = value!;
                    _selectedIds = _selectAll
                        ? _pagedEntries.map((e) => e['id'] as String).toList()
                        : [];
                  });
                },
              ),
              const Text("Select/Deselect All"),

            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Select")),
                  DataColumn(label: Text("Name")),
                  DataColumn(label: Text("Crop")),
                  DataColumn(label: Text("Genus")),
                  DataColumn(label: Text("ID")),
                ],
                rows: _pagedEntries.map((entry) {
                  final id = entry['id'] ?? '';
                  return DataRow(
                    selected: _selectedIds.contains(id),
                    onSelectChanged: (selected) {
                      setState(() {
                        if (selected!) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      });
                    },
                    cells: [
                      DataCell(Checkbox(
                        value: _selectedIds.contains(id),
                        onChanged: (val) {
                          setState(() {
                            if (val!) {
                              _selectedIds.add(id);
                            } else {
                              _selectedIds.remove(id);
                            }
                          });
                        },
                      )),
                      DataCell(Text(entry['Name'] ?? '')),
                      DataCell(Text(entry['Crop'] ?? '')),
                      DataCell(Text(entry['Genus'] ?? '')),
                      DataCell(Text(id)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Text("Page ${_currentPage + 1}"),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed:
                    (_currentPage + 1) * _rowsPerPage < _entries.length
                        ? () => setState(() => _currentPage++)
                        : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
