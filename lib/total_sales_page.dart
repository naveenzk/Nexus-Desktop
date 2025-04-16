import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nexus_desktop/database_helper.dart';

class TotalSalesPage extends StatefulWidget {
  const TotalSalesPage({super.key});

  @override
  _TotalSalesPageState createState() => _TotalSalesPageState();
}

class _TotalSalesPageState extends State<TotalSalesPage> {
  double totalSales = 0.0;
  int totalOrders = 0;
  double salesLast30Days = 0.0;
  int totalProductsSold = 0;

  List<Map<String, dynamic>> salesData = [];
  List<String> labels = [];
  List<Map<String, dynamic>> topProductsData = [];

  String selectedTimeframe = "Last Month"; // Default selection

  // Define your product categories
  final List<String> productCategories = [
    "Biryani",
    "Pulao",
    "Chicken Karahi",
    "Chicken Kaleji",
    "Qeema",
    "Daal Mach",
    "Channa",
    "Murgh Channa",
    "Anda Channa",
    "Aalo Anda",
    "Daal Channa",
    "Aalo Palak",
    "Mix Sabzi",
    "Kari Pakora",
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    fetchSalesData();
    fetchData();
  }

  Future<List<Map<String, dynamic>>> fetchSalesData() async {
    if (selectedTimeframe == "Last Month") {
      return await _dbHelper.fetchMonthlySales();
    } else if (selectedTimeframe == "Daily Sales") {
      return await _dbHelper.fetchDailySales();
    } else if (selectedTimeframe == "Top Products") {
      return await _dbHelper.fetchTopProducts();
    } else {
      return [];
    }
  }

  Future<void> fetchData() async {
    final stats = await _dbHelper.fetchDashboardStats();
    setState(() {
      totalSales = stats['totalSales'];
      totalOrders = stats['totalOrders'];
      salesLast30Days = stats['salesLast30Days'];
      totalProductsSold = stats['totalProductsSold'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOTAL SALES CONTAINER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade300, blurRadius: 5),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bar_chart,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        " TOTAL SALES",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Rs ${totalSales.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // BAR CHART WITH FUTURE BUILDER
            Container(
              height: 340,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade300, blurRadius: 5),
                ],
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchSalesData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text("Error loading data: ${snapshot.error}"),
                    );
                  }

                  // Always use the data, even if empty
                  salesData = snapshot.data ?? [];

                  if (selectedTimeframe == "Top Products") {
                    // For Top Products, ensure we have data for all categories
                    if (salesData.isEmpty) {
                      // Create empty data for all categories
                      salesData =
                          productCategories
                              .map(
                                (category) => {
                                  'product_name': category,
                                  'quantity': 0,
                                },
                              )
                              .toList();
                    }
                    return _buildTopProductsChart();
                  } else {
                    // For other timeframes, ensure we have data for all periods
                    if (salesData.isEmpty) {
                      if (selectedTimeframe == "Last Month") {
                        // Create empty data for 4 weeks
                        salesData = List.generate(
                          4,
                          (index) => {
                            'week_name': 'Week ${index + 1}',
                            'total_sales': 0.0,
                          },
                        );
                      } else {
                        // Create empty data for 7 days
                        salesData = List.generate(
                          7,
                          (index) => {
                            'day_name':
                                [
                                  'Sunday',
                                  'Monday',
                                  'Tuesday',
                                  'Wednesday',
                                  'Thursday',
                                  'Friday',
                                  'Saturday',
                                ][index],
                            'total_sales': 0.0,
                          },
                        );
                      }
                    }
                    return _buildSalesChart();
                  }
                },
              ),
            ),
            const SizedBox(height: 10),

            // TIMEFRAME DROPDOWN
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: selectedTimeframe,
                  underline: Container(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  items:
                      [
                        "Last Month",
                        "Daily Sales",
                        "Top Products", // New option
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedTimeframe = newValue;
                      });
                      fetchSalesData(); // Reload the data when the timeframe changes
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // STAT CARDS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard(
                  "Total Sales",
                  "Rs ${totalSales.toStringAsFixed(0)}",
                  Icons.attach_money,
                  Colors.purple,
                  Colors.purple.shade100,
                ),
                _buildStatCard(
                  "Total Orders",
                  "$totalOrders",
                  Icons.shopping_cart,
                  Colors.orange,
                  Colors.orange.shade100,
                ),
                _buildStatCard(
                  "Sales of Last 30 Days",
                  "Rs ${salesLast30Days.toStringAsFixed(0)}",
                  Icons.receipt,
                  Colors.red,
                  Colors.red.shade100,
                ),
                _buildStatCard(
                  "Total Products Sold",
                  "$totalProductsSold",
                  Icons.shopping_bag,
                  Colors.green,
                  Colors.green.shade100,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    // Generate labels based on the selected timeframe
    labels =
        selectedTimeframe == "Last Month"
            ? salesData.map<String>((e) => e['week_name'].toString()).toList()
            : salesData.map<String>((e) => e['day_name'].toString()).toList();

    return BarChart(
      BarChartData(
        maxY: _calculateMaxY(),
        minY: 0,
        barGroups: _getBarGroups(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            axisNameWidget: Text(
              "Sales Count",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              selectedTimeframe == "Last Month" ? "Weeks" : "Last 7 Days",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  double salesValue =
                      selectedTimeframe == "Daily Sales"
                          ? salesData[value.toInt()]['total_sales'] ?? 0.0
                          : selectedTimeframe == "Last Month"
                          ? salesData[value.toInt()]['total_sales']
                                  ?.toDouble() ??
                              0.0
                          : 0.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        labels[value.toInt()],
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      if (selectedTimeframe == "Daily Sales" ||
                          selectedTimeframe == "Last Month")
                        Column(
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "Rs ${salesValue.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 50,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildTopProductsChart() {
    final categoryData = {
      for (var item in salesData)
        item['category'].toString(): {
          'quantity': item['quantity']?.toDouble() ?? 0.0,
          'total_price': item['total_price']?.toDouble() ?? 0.0,
        },
    };

    // Fill missing categories with 0 values
    for (var category in productCategories) {
      categoryData.putIfAbsent(
        category,
        () => {'quantity': 0.0, 'total_price': 0.0},
      );
    }

    // Sort by quantity (descending)
    final sortedCategories =
        categoryData.entries.toList()..sort(
          (a, b) => b.value['quantity']!.compareTo(a.value['quantity']!),
        );

    // Prepare chart data
    List<BarChartGroupData> barGroups = [];
    List<String> categoryLabels = [];

    for (int i = 0; i < sortedCategories.length; i++) {
      final entry = sortedCategories[i];
      categoryLabels.add(entry.key);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entry.value['quantity']!,
              color: _getCategoryColor(entry.key),
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: 500, // Fixed max at 500 for quantities
        minY: 0,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < categoryLabels.length) {
                  final category = categoryLabels[value.toInt()];
                  final price =
                      sortedCategories[value.toInt()].value['total_price']!
                          .toInt();

                  return Column(
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Rs $price',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 50,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // Assign different colors to different categories
    final colors = [
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
      Colors.blue,
    ];

    int index = productCategories.indexOf(category) % colors.length;
    return colors[index];
  }

  double _calculateMaxY() {
    if (salesData.isEmpty) return 10;
    double maxSales = salesData
        .map((e) => e['total_sales'].toDouble())
        .reduce((a, b) => a > b ? a : b);
    if (maxSales <= 0) return 10;
    int exponent = maxSales.toInt().toString().length - 1;
    double roundFactor = pow(10, exponent).toDouble();
    return ((maxSales / roundFactor).ceil() * roundFactor).toDouble();
  }

  // ignore: unused_element
  double _calculateMaxYForTopProducts(
    List<MapEntry<String, dynamic>> categories,
  ) {
    if (categories.isEmpty) return 500; // Changed from 1000 to 500

    double maxQuantity = categories
        .map((e) => (e.value as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    // Round up to nearest 50, with minimum of 500
    return maxQuantity < 500 ? 500 : (maxQuantity / 50).ceil() * 50;
  }

  List<BarChartGroupData> _getBarGroups() {
    int totalBars = selectedTimeframe == "Daily Sales" ? 10 : salesData.length;

    return salesData.asMap().entries.map((entry) {
      int index = entry.key;
      double salesCount = entry.value['total_sales'].toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: salesCount,
            color: salesCount == 0 ? Colors.grey.shade300 : Colors.blue,
            width: (250 / totalBars).clamp(15, 25),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    Color bgColor,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(20),
        height: 120,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
