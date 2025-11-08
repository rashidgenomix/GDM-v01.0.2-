import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart';
import 'layout_screen.dart';

import 'login_screen.dart';
import '../components/qr_generator.dart';
import '../components/qr_scanner.dart';
import 'database_screen.dart';
import 'phenotyping_screen.dart';
import 'experiment_screen.dart';
import 'data_sheets_screen.dart';
import '../widgets/auth_guard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<String> titles = [
    'Home',
    'Generate QR',
    'Scan QR',
    'Database',
    'Phenotyping',
    'Experiment Setup',
    'Data Sheets',
  ];

  void _onItemTap(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _selectedIndex = index;
      });
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    final tabs = [
      buildHome(context),
      AuthGuard(child: QRGeneratorScreen()),
      AuthGuard(child: QRScanner()),
      AuthGuard(child: DatabaseScreen()),
      AuthGuard(child: PhenotypingScreen()),
      AuthGuard(child: ExperimentScreen()),
      AuthGuard(child: DataSheetsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          isLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Logged out")));
                  },
                )
              : TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text("Login", style: TextStyle(color: Colors.white)),
                ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFFF2FCE2)),
              child: Center(
                child: Text(
                  'GDM',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ),
            for (int i = 0; i < titles.length; i++)
              ListTile(
                leading: Icon(_getIcon(i)),
                title: Text(titles[i]),
                selected: i == _selectedIndex,
                onTap: () => _onItemTap(i),
              ),
          ],
        ),
      ),
      body: tabs[_selectedIndex],
    );
  }

  Widget buildHome(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {'icon': Icons.qr_code, 'label': 'Generate QR', 'index': 1, 'color': Colors.red},
      {'icon': Icons.qr_code_scanner, 'label': 'Scan QR', 'index': 2, 'color': Colors.purple},
      {'icon': Icons.storage, 'label': 'Database', 'index': 3, 'color': Colors.blue},
      {'icon': Icons.eco, 'label': 'Phenotyping', 'index': 4, 'color': Colors.orange},
      {'icon': Icons.science, 'label': 'Experiment Setup', 'index': 5, 'color': Colors.teal},
      {'icon': Icons.table_view, 'label': 'Data Sheets', 'index': 6, 'color': Colors.indigo},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Germplasm Data Manager",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text(
                "Efficiently manage and track your germplasm collection.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 15),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: features.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return Material(
                    color: Colors.white,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _onItemTap(feature['index']),
                      borderRadius: BorderRadius.circular(12),
                      splashColor: feature['color'].withOpacity(0.2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(feature['icon'], size: 48, color: feature['color']),
                            const SizedBox(height: 8),
                            Text(
                              feature['label'],
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),
              const Text(
                "Developed by Dr Rashid M Rana, PBG PMAS-AAUR",
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.qr_code;
      case 2:
        return Icons.qr_code_scanner;
      case 3:
        return Icons.storage;
      case 4:
        return Icons.eco;
      case 5:
        return Icons.science; // Experiment Setup
      case 6:
        return Icons.table_view; // Data Sheets
      default:
        return Icons.device_unknown;
    }
  }
}
