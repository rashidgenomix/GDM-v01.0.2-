import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _backupToCloud() {
    // Placeholder
  }

  void _clearLocalCache() {
    // Placeholder
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _backupToCloud,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Backup to Firebase"),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _clearLocalCache,
              icon: const Icon(Icons.delete_forever),
              label: const Text("Clear Local Cache (Future Use)"),
            ),
          ],
        ),
      ),
    );
  }
}