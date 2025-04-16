import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    Directory documentsDir = await getApplicationDocumentsDirectory();
    String databasesPath = join(documentsDir.path, 'nexus_desktop');

    String path = join(databasesPath, 'database.db');

    try {
      if (!await databaseExists(path)) {
        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load('assets/database.db');
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
      }
    } catch (e) {
      print("Error copying database: $e");
    }

    return await openDatabase(path);
  }

  Future<List<Map<String, dynamic>>> fetchWeeklySales() async {
    final db = await database;
    String query = '''
    WITH Last4Weeks AS (
      SELECT date('now', '-3 weeks') AS start_of_week UNION ALL
      SELECT date('now', '-2 weeks') UNION ALL
      SELECT date('now', '-1 weeks') UNION ALL
      SELECT date('now', '-0 weeks')
    )
    SELECT 
      strftime('%W', l.start_of_week) AS week_number,
      COALESCE(SUM(o.total_amount), 0) AS total_sales
    FROM Last4Weeks l
    LEFT JOIN orders o ON strftime('%W', o.order_date) = strftime('%W', l.start_of_week)
    GROUP BY l.start_of_week
    ORDER BY l.start_of_week DESC;
    ''';

    final result = await db.rawQuery(query);
    return result.map((map) {
      return {
        'week_number': map['week_number'],
        'total_sales': (map['total_sales'] as num).toDouble(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTopProducts() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
    WITH today_sales AS (
      SELECT 
        od.product_id,
        od.quantity,
        m.product_name,
        m.price
      FROM order_details od
      JOIN orders o ON od.order_id = o.order_id
      JOIN menu m ON od.product_id = m.product_id
      WHERE date(o.order_date) = ?
    ),
    categorized_sales AS (
      SELECT
        CASE
          WHEN product_name LIKE '%Biryani%' THEN 'Biryani'
          WHEN product_name LIKE '%Pulao%' THEN 'Pulao'
          WHEN product_name IN ('Chicken Karahi Half', 'Chicken Karahi Full') THEN 'Chicken Karahi'
          WHEN product_name IN ('Chicken Kaleji Half', 'Chicken Kaleji Full') THEN 'Chicken Kaleji'
          WHEN product_name IN ('Qeema Half', 'Qeema Full') THEN 'Qeema'
          WHEN product_name IN ('Daal Mach Half', 'Daal Mach Full') THEN 'Daal Mach'
          WHEN product_name IN ('Channa Half', 'Channa Full') THEN 'Channa'
          WHEN product_name IN ('Murgh Channa Half', 'Murgh Channa Full') THEN 'Murgh Channa'
          WHEN product_name IN ('Anda Channa Half', 'Anda Channa Full') THEN 'Anda Channa'
          WHEN product_name IN ('Aalo Anda Half', 'Aalo Anda Full') THEN 'Aalo Anda'
          WHEN product_name IN ('Daal Channa Half', 'Daal Channa Full') THEN 'Daal Channa'
          WHEN product_name IN ('Aalo Palak Half', 'Aalo Palak Full') THEN 'Aalo Palak'
          WHEN product_name IN ('Mix Sabzi Half', 'Mix Sabzi Full') THEN 'Mix Sabzi'
          WHEN product_name IN ('Kari Pakora Half', 'Kari Pakora Full') THEN 'Kari Pakora'
          ELSE 'Other'
        END AS category,
        SUM(quantity) as quantity,
        SUM(quantity * price) as total_price
      FROM today_sales
      GROUP BY category
      HAVING category != 'Other'
    )
    SELECT * FROM categorized_sales
    ORDER BY quantity DESC
  ''',
      [today],
    );
  }

  Future<List<Map<String, dynamic>>> fetchMenuItems() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT menu.product_id, menu.product_name, COALESCE(menu.price, 0) AS price, categories.category_name
      FROM menu
      INNER JOIN categories ON menu.category_id = categories.category_id
      ORDER BY categories.category_id, menu.product_id
    ''');
  }

  Future<List<Map<String, dynamic>>> fetchMenuData() async {
    final db = await database;
    try {
      final data = await db.rawQuery('''
      SELECT menu.product_id, menu.product_name, COALESCE(menu.price, 0) AS price, categories.category_name 
      FROM menu 
      INNER JOIN categories ON menu.category_id = categories.category_id;
      ''');
      print("Fetched Menu Data: $data");
      return data;
    } catch (e) {
      print("Error fetching menu data: $e");
      return [];
    }
  }

  Future<List<String>> fetchCategories() async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'categories',
      columns: ['category_name'],
    );
    return result.map((e) => e['category_name'].toString()).toList();
  }

  Future<int> updateDish(
    int productId,
    String name,
    String price,
    String category,
  ) async {
    final db = await database;

    List<Map<String, dynamic>> categoryResult = await db.query(
      'categories',
      columns: ['category_id'],
      where: 'category_name = ?',
      whereArgs: [category],
    );

    if (categoryResult.isEmpty) {
      throw Exception("Category not found");
    }

    int categoryId = categoryResult.first['category_id'];

    return await db.update(
      'menu',
      {'product_name': name, 'price': price, 'category_id': categoryId},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final db = await database;

    final totalSalesResult = await db.rawQuery(
      'SELECT SUM(total_amount) AS total_sales FROM orders',
    );
    double totalSales = totalSalesResult.first['total_sales'] as double? ?? 0.0;

    final totalOrdersResult = await db.rawQuery(
      'SELECT COUNT(order_id) AS total_orders FROM orders',
    );
    int totalOrders = totalOrdersResult.first['total_orders'] as int? ?? 0;

    final salesLast30DaysResult = await db.rawQuery(
      "SELECT SUM(total_amount) AS sales_30_days FROM orders WHERE order_date >= date('now', '-30 days')",
    );
    double salesLast30Days =
        salesLast30DaysResult.first['sales_30_days'] as double? ?? 0.0;

    final totalProductsResult = await db.rawQuery(
      "SELECT SUM(quantity) AS total_products FROM order_details",
    );
    int totalProductsSold =
        totalProductsResult.first['total_products'] as int? ?? 0;

    return {
      'totalSales': totalSales,
      'totalOrders': totalOrders,
      'salesLast30Days': salesLast30Days,
      'totalProductsSold': totalProductsSold,
    };
  }

  /*Future<List<Map<String, dynamic>>> fetchCategorySales() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT 
        c.category_name,
        COALESCE(SUM(sales_count), 0) AS sales_count
    FROM categories c
    LEFT JOIN (
        SELECT 
            m.category_id,
            COUNT(o.order_id) AS sales_count
        FROM order_details o
        JOIN menu m ON o.product_id = m.product_id
        WHERE o.order_id IN (
            SELECT order_id FROM orders
            WHERE order_date >= date('now', '-1 month')
        )
        GROUP BY m.category_id
    ) s ON c.category_id = s.category_id
    GROUP BY c.category_name
    ORDER BY sales_count DESC;
    ''');
  }*/

  Future<List<Map<String, dynamic>>> fetchProductSales() async {
    final db = await database;
    return await db.rawQuery('''
    WITH ProductGroups AS (
        SELECT 
            SUBSTR(m.product_name, 1, INSTR(m.product_name || ' ', ' ') - 1) AS base_product,
            c.category_name,
            o.order_id
        FROM order_details o
        JOIN menu m ON o.product_id = m.product_id
        JOIN categories c ON m.category_id = c.category_id
    )
    SELECT base_product AS product_name, category_name, COUNT(*) AS sales_count
    FROM ProductGroups
    GROUP BY base_product, category_name
    ORDER BY sales_count DESC;
  ''');
  }

  Future<List<Map<String, dynamic>>> fetchMonthlySales() async {
    final db = await database;
    final result = await db.rawQuery('''
    WITH Last4Weeks AS (
      SELECT date('now', '-28 days') AS start_date, 'Week 1' AS week_name UNION ALL
      SELECT date('now', '-21 days'), 'Week 2' UNION ALL
      SELECT date('now', '-14 days'), 'Week 3' UNION ALL
      SELECT date('now', '-7 days'), 'Week 4'
    )
    SELECT 
      l.week_name,
      COALESCE(SUM(o.total_amount), 0) AS total_sales
    FROM Last4Weeks l
    LEFT JOIN orders o ON date(o.order_date) >= l.start_date 
                        AND date(o.order_date) < date(l.start_date, '+7 days')
    GROUP BY l.week_name
    ORDER BY l.start_date;
  ''');

    return result.map((map) {
      return {
        'week_name': map['week_name'],
        'total_sales': (map['total_sales'] as num).toDouble(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchDailySales() async {
    final db = await database;
    final result = await db.rawQuery('''
  WITH Last7Days AS (
    SELECT date('now', '-6 days') AS sale_date UNION ALL
    SELECT date('now', '-5 days') UNION ALL
    SELECT date('now', '-4 days') UNION ALL
    SELECT date('now', '-3 days') UNION ALL
    SELECT date('now', '-2 days') UNION ALL
    SELECT date('now', '-1 days') UNION ALL
    SELECT date('now', '-0 days')
  )
  SELECT 
    CASE 
      WHEN strftime('%w', l.sale_date) = '0' THEN 'Sunday'
      WHEN strftime('%w', l.sale_date) = '1' THEN 'Monday'
      WHEN strftime('%w', l.sale_date) = '2' THEN 'Tuesday'
      WHEN strftime('%w', l.sale_date) = '3' THEN 'Wednesday'
      WHEN strftime('%w', l.sale_date) = '4' THEN 'Thursday'
      WHEN strftime('%w', l.sale_date) = '5' THEN 'Friday'
      WHEN strftime('%w', l.sale_date) = '6' THEN 'Saturday'
    END AS day_name,
    COALESCE(SUM(o.total_amount), 0) AS total_sales
  FROM Last7Days l
  LEFT JOIN orders o ON date(o.order_date) = l.sale_date
  GROUP BY l.sale_date
  ORDER BY l.sale_date DESC;
  ''');

    return result.map((map) {
      return {
        'day_name': map['day_name'],
        'total_sales': (map['total_sales'] as num).toDouble(),
      };
    }).toList();
  }

  Future<int> insertOrder(double totalAmount, String orderDate) async {
    final db = await database;
    return await db.insert('orders', {
      'order_date': orderDate,
      'total_amount': totalAmount,
    });
  }

  Future<int?> getProductId(String productName) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'menu',
      columns: ['product_id'],
      where: 'product_name = ?',
      whereArgs: [productName],
    );
    return result.isNotEmpty ? result.first['product_id'] as int? : null;
  }

  Future<int> insertOrderDetail(
    int orderId,
    int productId,
    int quantity,
  ) async {
    final db = await database;
    return await db.insert('order_details', {
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
    });
  }

  Future<String?> getMostRecentDate() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT date(order_date) as recent_date FROM orders 
      ORDER BY order_date DESC 
      LIMIT 1
    ''');
    return result.isNotEmpty ? result.first['recent_date'] as String? : null;
  }

  Future<double> getTodaySales() async {
    final db = await database;
    final recentDate = await getMostRecentDate();
    if (recentDate == null) return 0.0;

    final result = await db.rawQuery(
      '''
      SELECT SUM(total_amount) as total FROM orders 
      WHERE date(order_date) = ?
      ''',
      [recentDate],
    );

    return result.first['total'] != null
        ? (result.first['total'] as double)
        : 0.0;
  }

  Future<double> getWeeklySales() async {
    final db = await database;
    final recentDate = await getMostRecentDate();
    if (recentDate == null) return 0.0;

    final result = await db.rawQuery(
      '''
      SELECT SUM(total_amount) as total FROM orders 
      WHERE date(order_date) BETWEEN date(?, '-6 days') AND ?
      ''',
      [recentDate, recentDate],
    );

    return result.first['total'] != null
        ? (result.first['total'] as double)
        : 0.0;
  }

  Future<double> getMonthlySales() async {
    final db = await database;
    final recentDate = await getMostRecentDate();
    if (recentDate == null) return 0.0;

    final result = await db.rawQuery(
      '''
      SELECT SUM(total_amount) as total FROM orders 
      WHERE date(order_date) BETWEEN date(?, '-29 days') AND ?
      ''',
      [recentDate, recentDate],
    );

    return result.first['total'] != null
        ? (result.first['total'] as double)
        : 0.0;
  }
}
