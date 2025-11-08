import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'database_screen.dart';
import '../widgets/auth_guard.dart';
import '../components/qr_generator.dart';
import '../components/qr_scanner.dart';
import 'phenotyping_screen.dart';
import 'descriptor_screen.dart';
import 'layout_screen.dart';
import 'dashboard_screen.dart';
import 'user_logs_screen.dart';
import 'settings_screen.dart';



class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  int _selectedIndex = 0;

  final List<String> titles = [
    'Home',
    'Generate QR',
    'Scan QR',
    'Database',
    'Phenotyping',
    'Descriptors',
    'Experiment Layout',
    'Dashboard',
    'User Logs',
    'Settings'
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
    final tabs = [
      HomeScreen(),
      AuthGuard(child: QRGeneratorScreen()),
      const AuthGuard(child: QRScanner()),
      AuthGuard(child: DatabaseScreen()),
      const AuthGuard(child: PhenotypingScreen()),
      const AuthGuard(child: DescriptorScreen()),
      const AuthGuard(child: LayoutScreen()),
      const AuthGuard(child: DashboardScreen()),
      const AuthGuard(child: UserLogsScreen()),
      const AuthGuard(child: SettingsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: Colors.green.shade200,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green.shade200),
              child: const Center(
                child: Text(
                  'Germplasm App',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            for (int i = 0; i < titles.length; i++)
              ListTile(
                leading: Icon(_getIcon(i), color: Colors.green),
                title: Text(titles[i]),
                selected: i == _selectedIndex,
                onTap: () => _onItemTap(i),
              )
          ],
        ),
      ),
      body: tabs[_selectedIndex],
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
        return Icons.description;
      case 6:
        return Icons.grid_3x3;
      case 7:
        return Icons.dashboard;
      case 8:
        return Icons.history;
      case 9:
        return Icons.settings;
      default:
        return Icons.device_unknown;
    }
  }
}