import 'package:flutter/material.dart';
import 'database_helper.dart';

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

  Future<void> resetDailySales() async {
    final db = await dbHelper.database;
    final recentDate = await dbHelper.getMostRecentDate();
    if (recentDate == null) return;

    // Get today's date in the same format as stored in the database
    final today = DateTime.now();
    final todayString =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Proceed only if the recentDate is today's date
    if (recentDate == todayString) {
      // Delete order_details first
      await db.rawDelete(
        '''
      DELETE FROM order_details 
      WHERE order_id IN (
        SELECT order_id FROM orders 
        WHERE date(order_date) = ?
      )
      ''',
        [recentDate],
      );

      // Then delete the orders
      await db.rawDelete(
        '''
      DELETE FROM orders 
      WHERE date(order_date) = ?
      ''',
        [recentDate],
      );

      await fetchSalesData();
    }
  }

  Future<void> resetWeeklySales() async {
    final db = await dbHelper.database;
    final recentDate = await dbHelper.getMostRecentDate();
    if (recentDate == null) return;

    // Delete order_details first
    await db.rawDelete(
      '''
      DELETE FROM order_details 
      WHERE order_id IN (
        SELECT order_id FROM orders 
        WHERE date(order_date) BETWEEN date(?, '-6 days') AND ?
      )
    ''',
      [recentDate, recentDate],
    );

    // Then delete the orders
    await db.rawDelete(
      '''
      DELETE FROM orders 
      WHERE date(order_date) BETWEEN date(?, '-6 days') AND ?
    ''',
      [recentDate, recentDate],
    );

    await fetchSalesData();
  }

  Future<void> resetMonthlySales() async {
    final db = await dbHelper.database;
    final recentDate = await dbHelper.getMostRecentDate();
    if (recentDate == null) return;

    // Delete order_details first
    await db.rawDelete(
      '''
      DELETE FROM order_details 
      WHERE order_id IN (
        SELECT order_id FROM orders 
        WHERE date(order_date) BETWEEN date(?, '-29 days') AND ?
      )
    ''',
      [recentDate, recentDate],
    );

    // Then delete the orders
    await db.rawDelete(
      '''
      DELETE FROM orders 
      WHERE date(order_date) BETWEEN date(?, '-29 days') AND ?
    ''',
      [recentDate, recentDate],
    );

    await fetchSalesData();
  }

  Future<void> resetAll() async {
    final db = await dbHelper.database;

    // Delete all order_details
    await db.rawDelete('DELETE FROM order_details');

    // Delete all orders
    await db.rawDelete('DELETE FROM orders');

    await fetchSalesData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Reset Options",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 96, 140, 162),
        elevation: 4,
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
              onReset: resetMonthlySales,
            ),
            _buildResetCard(
              title: "Weekly Sales",
              value: "Rs ${weeklySales.toStringAsFixed(0)}",
              icon: Icons.trending_up,
              color: Colors.blueAccent,
              onReset: resetWeeklySales,
            ),
            _buildResetCard(
              title: "Daily Sales",
              value: "Rs ${dailySales.toStringAsFixed(0)}",
              icon: Icons.trending_up,
              color: const Color.fromARGB(255, 45, 20, 206),
              onReset: resetDailySales,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: resetAll,
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
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
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
