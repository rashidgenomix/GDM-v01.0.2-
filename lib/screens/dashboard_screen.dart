import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int germplasmCount = 0;
  int descriptorCount = 0;
  int layoutCount = 0;
  int phenotypingCount = 0;
  Map<String, int> layoutDistribution = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final germplasmSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('germplasm_entries')
        .get();

    final descSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('descriptors')
        .get();

    final layoutSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experiment_layouts')
        .get();

    Map<String, int> layoutTypes = {};
    for (var doc in layoutSnap.docs) {
      String type = doc.data()['design'] ?? 'Unknown';
      layoutTypes[type] = (layoutTypes[type] ?? 0) + 1;
    }

    int phenoTotal = 0;
    final phenoLayouts = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('phenotyping_data')
        .get();

    for (var layoutDoc in phenoLayouts.docs) {
      final collectionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('phenotyping_data')
          .doc(layoutDoc.id)
          .collection('accessions')
          .get();

      phenoTotal += collectionsSnap.docs.length;
    }

    setState(() {
      germplasmCount = germplasmSnap.size;
      descriptorCount = descSnap.size;
      layoutCount = layoutSnap.size;
      phenotypingCount = phenoTotal;
      layoutDistribution = layoutTypes;
      isLoading = false;
    });
  }

  Widget buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, size: 32, color: color),
        title: Text(title),
        trailing: Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget buildBarChart() {
    final items = layoutDistribution.entries.toList();
    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                if (val.toInt() < items.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(items[val.toInt()].key, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(items.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [BarChartRodData(toY: items[index].value.toDouble(), width: 20)],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), backgroundColor: Colors.indigo),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 10),
                buildStatCard('Germplasm Entries', germplasmCount, Icons.storage, Colors.teal),
                buildStatCard('Descriptors', descriptorCount, Icons.list_alt, Colors.deepOrange),
                buildStatCard('Experiment Layouts', layoutCount, Icons.grid_on, Colors.deepPurple),
                buildStatCard('Phenotyping Records', phenotypingCount, Icons.science, Colors.brown),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Layout Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (layoutDistribution.isNotEmpty)
                  SizedBox(height: 250, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: buildBarChart()))
                else
                  const Center(child: Text("No layout data available")),
              ],
            ),
    );
  }
}