import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class QRGenerator extends StatefulWidget {
  const QRGenerator({super.key});

  @override
  State<QRGenerator> createState() => _QRGeneratorState();
}

class _QRGeneratorState extends State<QRGenerator> {
  String? _selectedAccession;
  List<String> _batchSelections = [];
  List<Map<String, dynamic>> _entries = [];
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _loadEntries() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('germplasm_entries')
        .get();

    setState(() {
      _entries = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Widget _buildQRCodeWithLabel(String data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 200.0,
        ),
        const SizedBox(height: 8),
        Text(data, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Future<void> _saveSingleQRAsPDF(String data) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    final image = await _screenshotController.captureFromWidget(
      _buildQRCodeWithLabel(data),
      pixelRatio: 2.0,
    );

    final pdf = pw.Document();
    final img = pw.MemoryImage(image!);
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Image(img, width: 200, height: 200),
              pw.SizedBox(height: 10),
              pw.Text(data, style: const pw.TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    final dir = await getExternalStorageDirectory();
    final file = File("${dir!.path}/QR_$data.pdf");
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved to ${file.path}")),
    );
  }

  Future<void> _saveBatchQRAsPDF() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    final pdf = pw.Document();

    for (final acc in _batchSelections) {
      final image = await _screenshotController.captureFromWidget(
        _buildQRCodeWithLabel(acc),
        pixelRatio: 2.0,
      );
      final img = pw.MemoryImage(image!);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Image(img, width: 200, height: 200),
                pw.SizedBox(height: 10),
                pw.Text(acc, style: const pw.TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    final dir = await getExternalStorageDirectory();
    final file = File("${dir!.path}/Batch_QRCodes.pdf");
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Batch PDF saved at ${file.path}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Generator")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text("Single QR Generator",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedAccession,
                hint: const Text("Select Accession Number"),
                items: _entries
                    .map((e) => e["Accession Number"].toString())
                    .map((acc) => DropdownMenuItem(
                          value: acc,
                          child: Text(acc),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccession = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              if (_selectedAccession != null)
                Column(
                  children: [
                    Screenshot(
                      controller: _screenshotController,
                      child: _buildQRCodeWithLabel(_selectedAccession!),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _saveSingleQRAsPDF(_selectedAccession!),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Download QR as PDF"),
                    ),
                  ],
                ),
              const Divider(height: 40),
              const Text("Batch QR Generator",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _entries
                    .map((e) => e["Accession Number"].toString())
                    .map((acc) => FilterChip(
                          label: Text(acc),
                          selected: _batchSelections.contains(acc),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _batchSelections.add(acc);
                              } else {
                                _batchSelections.remove(acc);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              if (_batchSelections.isNotEmpty)
                Column(
                  children: [
                    const Text("Download Batch QR Codes"),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _saveBatchQRAsPDF,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Download All as PDF"),
                    )
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
