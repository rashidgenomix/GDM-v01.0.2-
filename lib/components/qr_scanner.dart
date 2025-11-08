import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/phenotyping_screen.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScanner> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  String? _scannedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleImageUpload() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);


    if (pickedFile == null) return;

    final tempDir = await getTemporaryDirectory();
    final imageFile = await File(pickedFile.path).copy('${tempDir.path}/temp_qr.png');

    final result = await _controller.analyzeImage(imageFile.path);
    if (result != null && result.barcodes.isNotEmpty) {
      setState(() {
        _scannedCode = result.barcodes.first.rawValue;
      });
      _showResultDialog(_scannedCode!);
    }
  }

  void _showResultDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("QR Code Found"),
        content: Text("Accession: $code"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Start Phenotyping"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhenotypingScreen(qrAccession: code),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Scanner")),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes.first.rawValue;
              if (code != null && code != _scannedCode) {
                setState(() => _scannedCode = code);
                _showResultDialog(code);
              }
            },
          ),
          Positioned(
            bottom: 75,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text("Scan from Image"),
              onPressed: _handleImageUpload,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }
}
