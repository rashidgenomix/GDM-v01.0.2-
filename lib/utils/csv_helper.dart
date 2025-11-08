import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

class CSVHelper {
  static Future<void> exportToCSV(List<Map<String, dynamic>> data, String filename) async {
    // Prepare header
    if (data.isEmpty) return;
    final headers = data.first.keys.toList();
    final csvBuffer = StringBuffer();
    csvBuffer.writeln(headers.join(','));

    // Add rows
    for (var row in data) {
      csvBuffer.writeln(headers.map((key) => '"${row[key] ?? ''}"').join(','));
    }

    final csvData = csvBuffer.toString();

    if (kIsWeb) {
      // For Web
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // For Android
      final status = await Permission.storage.request();
      if (!status.isGranted) return;

      final directory = await getExternalStorageDirectory();
      final path = '${directory!.path}/$filename';
      final file = File(path);
      await file.writeAsString(csvData);
    }
  }
}
