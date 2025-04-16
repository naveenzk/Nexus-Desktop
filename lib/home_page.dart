import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:nexus_desktop/admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:nexus_desktop/database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bismillah Pakwan Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.yellow,
        scaffoldBackgroundColor: const Color(0xFFFFDB58),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F5),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
      ),
      home: const POSScreen(),
    );
  }
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final List<OrderItem> _orderItems = [];
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  int orderId = 0;

  void _addToOrder(String name, double price, int productId) {
    final existingItemIndex = _orderItems.indexWhere(
      (item) => item.name == name && item.price == price,
    );

    setState(() {
      if (existingItemIndex >= 0) {
        _orderItems[existingItemIndex].quantity++;
      } else {
        _orderItems.add(
          OrderItem(
            name: name,
            price: price,
            quantity: 1,
            productId: productId,
          ),
        );
      }
    });
  }

  Map<String, List<MenuItem>> _menuItemsByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    try {
      final menuItems = await _databaseHelper.fetchMenuItems();

      final Map<String, List<MenuItem>> categorizedMenuItems = {};
      for (var item in menuItems) {
        final category = item['category_name'];
        final menuItem = MenuItem(
          name: item['product_name'],
          price: item['price'],
          productId: item['product_id'],
        );

        if (categorizedMenuItems.containsKey(category)) {
          categorizedMenuItems[category]!.add(menuItem);
        } else {
          categorizedMenuItems[category] = [menuItem];
        }
      }
      setState(() {
        _menuItemsByCategory = categorizedMenuItems;
      });
    } catch (e) {
      setState(() {});
    }
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
    } else {
      setState(() {
        _orderItems[index].quantity = newQuantity;
      });
    }
  }

  double get _totalAmount {
    return _orderItems.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  Future<Map<String, String>> _fetchAdminCredentials() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'admin',
      columns: ['username', 'password'],
    );

    if (result.isNotEmpty) {
      return {
        'username': result[0]['username'],
        'password': result[0]['password'],
      };
    } else {
      throw Exception('Admin credentials not found');
    }
  }

  void _showAdminLogin(BuildContext context) {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    Future<void> login() async {
      try {
        final adminCredentials = await _fetchAdminCredentials();

        if (usernameController.text == adminCredentials['username'] &&
            passwordController.text == adminCredentials['password']) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminDashboard()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid credentials'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Admin Login'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  login();
                },
                child: const Text('Login'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
    );
  }

  Future<void> _saveOrder() async {
    // Get the current date
    String orderDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final db = await _databaseHelper.database;

      await db.transaction((txn) async {
        int orderId = await txn.insert('orders', {
          'order_date': orderDate,
          'total_amount': _totalAmount,
        });

        for (var item in _orderItems) {
          await txn.insert('order_details', {
            'order_id': orderId,
            'product_id': item.productId,
            'quantity': item.quantity,
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _orderItems.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //BILLL
  Future<void> _printBill() async {
    final pdf = pw.Document();
    final String formattedDate = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());
    final String fileName = 'Bill_$formattedDate.pdf';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          200 * PdfPageFormat.mm,
        ).applyMargin(left: 2, right: 2, top: 2, bottom: 2),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Restaurant name
              pw.Center(
                child: pw.Text(
                  'BPC PAKWAN CENTER',
                  style: pw.TextStyle(
                    fontSize: 13, // Smaller font size
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),

              // Bill details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bill #: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Date: ${_dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9), // Smaller font size
                  ),
                ],
              ),
              pw.SizedBox(height: 10), // Reduced spacing
              // Table for items
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(5),
                  ),
                ),
                child: pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(width: 0.5),
                  ),
                  columnWidths: {
                    // 0: const pw.FixedColumnWidth(25), // Smaller column width
                    0: const pw.FlexColumnWidth(80), // Adjusted column width
                    1: const pw.FixedColumnWidth(23), // Smaller column width
                    2: const pw.FixedColumnWidth(33), // Smaller column width
                    3: const pw.FixedColumnWidth(46), // Smaller column width
                  },
                  children: [
                    // Table header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        //  pw.Padding(
                        // padding: const pw.EdgeInsets.all(0.7), // Reduced padding----4
                        // child: pw.Text(
                        //  'S.No',
                        //  style: pw.TextStyle(
                        //    fontSize: 10, // Smaller font size
                        //    fontWeight: pw.FontWeight.bold,
                        //  ),
                        // ),
                        //  ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(
                            1.0,
                          ), // Reduced padding----4
                          child: pw.Text(
                            'ITEM',
                            style: pw.TextStyle(
                              fontSize: 9, // Smaller font size
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(
                            1,
                          ), // Reduced padding------4
                          child: pw.Text(
                            'QTY',
                            style: pw.TextStyle(
                              fontSize: 9, // Smaller font size
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(
                            1,
                          ), // Reduced padding-----4
                          child: pw.Text(
                            'RATE',
                            style: pw.TextStyle(
                              fontSize: 9, // Smaller font size
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(
                            1,
                          ), // Reduced padding----4
                          child: pw.Text(
                            'AMOUNT',
                            style: pw.TextStyle(
                              fontSize: 9, // Smaller font size ---8
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Table rows for each item
                    ..._orderItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return pw.TableRow(
                        decoration:
                            index % 2 == 0
                                ? const pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                )
                                : null,
                        children: [
                          // pw.Padding(
                          // padding: const pw.EdgeInsets.all(4.0), // Reduced padding
                          // child: pw.Text(
                          // '${index + 1}',
                          //style: const pw.TextStyle(fontSize: 9), // Smaller font size
                          // ),
                          //   ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(
                              4.0,
                            ), // Reduced padding
                            child: pw.Text(
                              item.name,
                              style: pw.TextStyle(
                                fontWeight:
                                    pw
                                        .FontWeight
                                        .bold, // Use pw.FontWeight instead of FontWeight
                                fontSize: 10, // Adjust font size
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(
                              4.0,
                            ), // Reduced padding
                            child: pw.Text(
                              '${item.quantity}',
                              style: const pw.TextStyle(
                                fontSize: 9,
                              ), // Smaller font size
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(
                              4.0,
                            ), // Reduced padding
                            child: pw.Text(
                              '${item.price.toInt()}',
                              style: pw.TextStyle(
                                fontWeight:
                                    pw
                                        .FontWeight
                                        .bold, // Use pw.FontWeight instead of FontWeight
                                fontSize: 10, // Adjust font size
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(
                              4.0,
                            ), // Reduced padding
                            child: pw.Text(
                              (item.price * item.quantity).toStringAsFixed(0),
                              style: const pw.TextStyle(
                                fontSize: 9,
                              ), // Smaller font size
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10), // Reduced spacing
              // Total amount
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 80, // Adjusted width
                          child: pw.Text(
                            'TOTAL:',
                            style: pw.TextStyle(
                              fontSize: 10, // Smaller font size
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Container(
                          width: 60, // Adjusted width
                          child: pw.Text(
                            'Rs. ${_totalAmount.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              fontSize: 10, // Smaller font size
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2), // Reduced spacing -----4
              // Powered by Trust Nexus
              pw.Center(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: '\nPowered by ', // Normal text
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.TextSpan(
                        text: 'Trust Nexus', // Bold text
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'For Software Development: 0303-8184136',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 10), // Adds spacing before cutting
              // Page Break (forces next receipt to print separately)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  '\n\n\n',
                ), // Adds blank space to force page break
              ),
            ],
          );
        },
      ),
    );

    Directory? directory;
    if (Platform.isWindows) {
      directory = Directory(
        '${Platform.environment['USERPROFILE']}\\Documents\\nexus_desktop',
      );
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final String path = '${directory.path}\\$fileName';
    final File file = File(path);
    await file.writeAsBytes(await pdf.save());

    //1st Option
    final List<Printer> printers = await Printing.listPrinters();

    Printer? defaultPrinter;
    if (printers.isNotEmpty) {
      defaultPrinter = printers.firstWhere(
        (printer) => printer.isDefault,
        orElse:
            () =>
                printers
                    .first, // Fallback to the first printer if no default found
      );
    }

    if (defaultPrinter != null) {
      await Printing.directPrintPdf(
        printer: defaultPrinter,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer found. Please connect a printer.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    //2nd Option
    // **Get the list of available printers**
    /*final List<Printer> printers = await Printing.listPrinters();

    if (printers.isNotEmpty) {
      // **Automatically use the first available printer**
      await Printing.directPrintPdf(
        printer: printers.first,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } else {
      // **Show Snackbar if no printer is found**
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer found. Please connect a printer.'),
          backgroundColor: Colors.red,
        ),
      );
    }*/

    //3rd Option

    // **Check for a default printer before sending the job**
    /* Printer? defaultPrinter = await Printing.pickPrinter(context: context);

    if (defaultPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer selected. Please select a printer.'),
          backgroundColor: Color.fromARGB(255, 255, 0, 0),
        ),
      );
      return;
    }

    // **Send PDF to the printer**
    await Printing.directPrintPdf(
      printer: defaultPrinter,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );*/

    String orderDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final db = await _databaseHelper.database;
      await db.transaction((txn) async {
        int orderId = await txn.insert('orders', {
          'order_date': orderDate,
          'total_amount': _totalAmount,
        });

        for (var item in _orderItems) {
          await txn.insert('order_details', {
            'order_id': orderId,
            'product_id': item.productId,
            'quantity': item.quantity,
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save order: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _orderItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120.0), // Adjusted height --120
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // White background
            border: Border(
              bottom: BorderSide(
                width: 1.0, // Thin line
                color: Colors.grey.shade300, // Light grey color
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: const Color.fromARGB(255, 10, 10, 10),
            elevation: 0,
            toolbarHeight: 140,
            leadingWidth: 150, // Increased space for logo  --160
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Container
                  Container(
                    width: 170, //---130
                    height: 96, //--60
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 15, 15, 15),
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: Image.asset(
                      'assets/black_logo.png',
                      // fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12), //---5
                ],
              ),
            ),

            // Centered Title
            title: const Text(
              'Bismillah Pakwan Center',
              style: TextStyle(
                fontSize: 50, // Adjusted for better UI
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,

            // Admin Login Button
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 40,
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showAdminLogin(context),
                  icon: const Icon(Icons.admin_panel_settings, size: 40),
                  label: const Text(
                    'Admin Login',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, // Added bold font weight
                      fontSize: 18, // Keeping your previous font size
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color.fromARGB(255, 2, 66, 126),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade100],
          ),
        ),
        child: Row(
          children: [
            // Menu Categories (75% of screen)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.deblur_outlined,
                            color: Color(0xFF1E3A8A),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Powered By: Trust Nexus\nContact: 0303-8184136',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, // Adjusted for readability
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _dateFormat.format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 0.68,
                        mainAxisSpacing: 1.0,
                        crossAxisSpacing: 1.0,
                        children:
                            _menuItemsByCategory.entries.map((entry) {
                              final category = entry.key;
                              final items = entry.value;
                              return MenuCategory(
                                title: category,
                                icon: _getCategoryIcon(category),
                                color: _getCategoryColor(category),
                                items: items,
                                onItemTap: _addToOrder,
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Order Details (25% of screen)
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 250, 249, 249),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        252,
                        251,
                        251,
                      ).withOpacity(0.05), //--white
                      blurRadius: 5,
                      offset: const Offset(-2, 0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              'Order Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Items: ${_orderItems.length}',
                                style: const TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  _orderItems.isEmpty
                                      ? null
                                      : () {
                                        setState(() {
                                          _orderItems.clear();
                                        });
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Item Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Quantity',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Price',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child:
                            _orderItems.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No items added yet',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Click on menu items to add them',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListView.separated(
                                    itemCount: _orderItems.length,
                                    separatorBuilder:
                                        (context, index) => Divider(
                                          height: 1,
                                          color: Colors.grey[300],
                                        ),
                                    itemBuilder: (context, index) {
                                      final item = _orderItems[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Rs. ${item.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                size: 20,
                                              ),
                                              color: Colors.red[400],
                                              onPressed: () {
                                                _updateQuantity(
                                                  index,
                                                  item.quantity - 1,
                                                );
                                              },
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 20,
                                              ),
                                              color: Colors.green[400],
                                              onPressed: () {
                                                _updateQuantity(
                                                  index,
                                                  item.quantity + 1,
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Rs. ${(item.price * item.quantity).toStringAsFixed(0)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                  ),
                                                  color: Colors.red[700],
                                                  onPressed: () {
                                                    _removeItem(index);
                                                  },
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                Text(
                                  'Rs. ${_totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _orderItems.isEmpty ? null : _saveOrder,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Record'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _orderItems.isEmpty ? null : _printBill,
                              icon: const Icon(Icons.print),
                              label: const Text('Print Bill'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _getCategoryIcon(String category) {
  switch (category) {
    case 'Biryani':
      return Icons.rice_bowl;
    case 'Pulao':
      return Icons.dinner_dining;
    case 'Salan':
      return Icons.soup_kitchen;
    case 'Roti':
      return Icons.bakery_dining;
    case 'Drinks':
      return Icons.local_drink;
    case 'Extras':
      return Icons.restaurant_menu;
    default:
      return Icons.restaurant_menu;
  }
}

Color _getCategoryColor(String category) {
  switch (category) {
    case 'Biryani':
      return const Color.fromARGB(255, 82, 3, 4);
    case 'Pulao':
      return const Color.fromARGB(255, 160, 131, 63);
    case 'Salan':
      return const Color.fromARGB(255, 7, 99, 88);
    case 'Roti':
      return const Color.fromARGB(255, 63, 88, 53);
    case 'Drinks':
      return const Color.fromARGB(255, 243, 123, 48);
    case 'Extras':
      return const Color.fromARGB(255, 161, 97, 97);
    default:
      return Colors.blue;
  }
}

class MenuItem {
  final String name;
  final double price;
  final int productId;

  const MenuItem({
    required this.name,
    required this.price,
    required this.productId,
  });
}

class OrderItem {
  final String name;
  final double price;
  final int productId;
  int quantity;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.productId,
  });
}

class MenuCategory extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<MenuItem> items;
  final Function(String, double, int) onItemTap;

  const MenuCategory({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    int totalSlots = 20; // Example: Adjust this based on your layout needs
    int filledSlots = items.length;
    int remainingSlots = totalSlots - filledSlots;

    // Fill remaining slots with empty items
    List<MenuItem> displayItems = List.from(items);
    for (int i = 0; i < remainingSlots; i++) {
      displayItems.add(MenuItem(name: ' ', price: 0, productId: -1));
    }
    return Card(
      margin: const EdgeInsets.all(2.0),

      ///6.0 ----card
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), //--12
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 17.0,
            ), // Decreased padding
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10), //---12
                topRight: Radius.circular(10), //---12
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20, // Decreased icon size  ----16
                ),
                const SizedBox(width: 6), // Decreased spacing -----6
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13, // Decreased font size ---14
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0), // Decreased padding ----6
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 2 items per row
                  childAspectRatio:
                      2.3, // Make buttons wider than tall   ---2.0
                  crossAxisSpacing: 4,

                  mainAxisSpacing: 4,
                ),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  return _buildMenuItemButton(displayItems[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemButton(MenuItem item) {
    return Card(
      margin: const EdgeInsets.all(2.0), // Decreased margin  --2.0
      elevation: 2, // Decreased elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6), // Decreased border radius
      ),
      child: InkWell(
        onTap:
            () =>
                item.name.isNotEmpty
                    ? onItemTap(item.name, item.price, item.productId)
                    : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4), // Decreased padding
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  item.name != '---' ? item.name : ' ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Decreased font size
                    height: 1.0, // Tighter line height
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              const SizedBox(height: 4.0), // Decreased spacing   ----2
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 1,
                  vertical: 1,
                ), // Decreased padding
                // decoration: BoxDecoration(
                // color: Colors.white.withOpacity(0.3),
                // borderRadius: BorderRadius.circular(3), //---10
                // ),
                child: Text(
                  item.price > 0 ? 'Rs. ${item.price.toStringAsFixed(0)}' : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
