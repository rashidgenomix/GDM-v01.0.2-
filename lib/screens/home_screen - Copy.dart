import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../components/qr_generator.dart';
import '../components/qr_scanner.dart';
import 'database_screen.dart';
import 'descriptor_screen.dart';
import 'layout_screen.dart';
import 'phenotyping_screen.dart';
import 'dashboard_screen.dart';
import 'user_logs_screen.dart';
import 'settings_screen.dart';
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
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    final tabs = [
      buildHome(context),
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
        backgroundColor: Colors.blueGrey,
        actions: [
          isLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    setState(() {});
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text("Logged out")));
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
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Center(
                child: Text(
                  'Germplasm App',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            for (int i = 0; i < titles.length; i++)
              ListTile(
                leading: Icon(_getIcon(i), color: Colors.blueGrey),
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

  Widget buildHome(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {'icon': Icons.qr_code, 'label': 'Generate QR', 'index': 1, 'color': Colors.red},
      {'icon': Icons.qr_code_scanner, 'label': 'Scan QR', 'index': 2, 'color': Colors.purple},
      {'icon': Icons.storage, 'label': 'Database', 'index': 3, 'color': Colors.blue},
      {'icon': Icons.eco, 'label': 'Phenotyping', 'index': 4, 'color': Colors.orange},
      {'icon': Icons.description, 'label': 'Descriptors', 'index': 5, 'color': Colors.teal},
      {'icon': Icons.grid_on, 'label': 'Exp. Layout', 'index': 6, 'color': Colors.pink},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                "Germplasm Data Manager",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Efficiently manage and track your germplasm collection.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 7; // Dashboard
                  });
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 4,
                  color: Colors.blueGrey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Icon(Icons.dashboard, color: Colors.blueGrey, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("📊 Dashboard Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 4),
                              Text("Tap to view insights and summaries.", style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
              const SizedBox(height: 30),
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
