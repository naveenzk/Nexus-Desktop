import 'package:flutter/material.dart';
import 'package:nexus_desktop/database_helper.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({super.key});

  @override
  _ResetPageState createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  double monthlySales = 0;
  double weeklySales = 0;
  double dailySales = 0;

  final DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    fetchSalesData();
  }

  Future<void> fetchSalesData() async {
    double daily = await dbHelper.getTodaySales();
    double weekly = await dbHelper.getWeeklySales();
    double monthly = await dbHelper.getMonthlySales();

    setState(() {
      dailySales = daily;
      weeklySales = weekly;
      monthlySales = monthly;
    });
  }

  Future<void> resetSales(Function resetFunction) async {
    await resetFunction();
    fetchSalesData(); // Refresh the sales data after reset
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFD7BDA6),
      appBar: AppBar(
        title: const Text(
          "Reset Options",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD7BDA6),
          ),
        ),
        backgroundColor: const Color(0xFF6d3914),
        elevation: 4,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildResetCard(
              title: "Monthly Sales",
              value: "Rs ${monthlySales.toStringAsFixed(0)}",
              icon: Icons.trending_up,
              color: const Color.fromARGB(255, 104, 205, 153),
              onReset: () => resetSales(dbHelper.resetMonthlySales),
            ),
            _buildResetCard(
              title: "Weekly Sales",
              value: "Rs ${weeklySales.toStringAsFixed(0)}",
              icon: Icons.trending_up,
              color: Colors.blueAccent,
              onReset: () => resetSales(dbHelper.resetWeeklySales),
            ),
            _buildResetCard(
              title: "Daily Sales",
              value: "Rs ${dailySales.toStringAsFixed(0)}",
              icon: Icons.trending_up,
              color: const Color.fromARGB(255, 45, 20, 206),
              onReset: () => resetSales(dbHelper.resetDailySales),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await dbHelper.resetAllSales();
          fetchSalesData();
        },
        backgroundColor: Colors.red.shade600,
        icon: const Icon(Icons.restore, color: Colors.white),
        label: const Text(
          "Reset All",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildResetCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onReset,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    double sw(double value) => screenWidth * (value / 1920);
    double sh(double value) => screenHeight * (value / 1080);

    return Card(
      color: Color.fromARGB(255, 241, 213, 187),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: sh(10)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: sh(20), horizontal: sw(24)),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(icon, color: color, size: 28),
                ),
                SizedBox(width: sw(16)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: sw(18),
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAB7843),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: sw(22),
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: onReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Reset"),
            ),
          ],
        ),
      ),
    );
  }
}
