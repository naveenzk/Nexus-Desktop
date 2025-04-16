import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus_desktop/database_helper.dart';

class DishPage extends StatefulWidget {
  const DishPage({super.key});

  @override
  State<DishPage> createState() => _DishPageState();
}

class _DishPageState extends State<DishPage> {
  List<Map<String, dynamic>> dishes = [];

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    final data = await _dbHelper.fetchMenuData();
    setState(() {
      dishes =
          data.map((item) {
            return {
              "sno": item['product_id'],
              "name": item['product_name'],
              "price": "RS ${(item['price'].round())}",
              "category": item['category_name'],
            };
          }).toList();
    });
  }

  void _editDish(int productId) async {
    BuildContext parentContext = context;
    // Find dish by productId
    Map<String, dynamic>? dish = dishes.firstWhere(
      (dish) => dish['sno'] == productId,
      orElse: () => {},
    );

    if (dish.isEmpty) {
      return; // Exit if no dish found
    }

    TextEditingController nameController = TextEditingController(
      text: dish['name'],
    );
    TextEditingController priceController = TextEditingController(
      text: dish['price'].replaceAll("RS ", ""),
    );

    // Fetch categories from the database
    List<String> categories = await _dbHelper.fetchCategories();
    String selectedCategory = dish['category']; // Default selection

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: 350,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit Dish",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF264653),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Dish Name",
                      prefixIcon: const Icon(
                        Icons.restaurant,
                        color: Color(0xFF2A9D8F),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: "Price",
                      prefixIcon: const Icon(
                        Icons.money,
                        color: Color(0xFFE76F51),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && double.tryParse(value) == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Only numeric values are allowed!"),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        priceController.clear(); // Clear invalid input
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Dropdown for Categories
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items:
                        categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                    onChanged: (newValue) {
                      selectedCategory = newValue!;
                    },
                    decoration: InputDecoration(
                      labelText: "Category",
                      prefixIcon: const Icon(
                        Icons.category,
                        color: Color(0xFFF4A261),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Update in Database
                          await _dbHelper.updateDish(
                            productId,
                            nameController.text,
                            priceController.text.isEmpty
                                ? '0'
                                : priceController
                                    .text, // Handle null/empty price
                            selectedCategory,
                          );

                          // Refresh UI
                          _loadDishes();

                          // Close the dialog first
                          Navigator.pop(context);

                          // Show success message after closing the dialog
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text("Item edited successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          "Save",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A9D8F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /*void _deleteDish(int index) async {
    int productId = dishes[index]['sno']; // Get product ID from list

    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Dish"),
            content: const Text("Are you sure you want to delete this dish?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // Cancel
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // Delete from database
                  await _dbHelper.deleteDish(productId);

                  // Remove from list and update UI
                  setState(() {
                    dishes.removeAt(index);
                    //_updateSerialNumbers(); // Update serial numbers after deletion
                  });

                  Navigator.pop(context); // Close dialog
                },
                icon: const Icon(Icons.delete, color: Colors.white),
                label: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Red color for delete action
                ),
              ),
            ],
          ),
    );
  }

  // Update serial numbers after deletion
  /*void _updateSerialNumbers() {
    for (int i = 0; i < dishes.length; i++) {
      dishes[i]['sno'] = i + 1;
    }
  }*/

  void _addNewDish() async {
    List<String> categories =
        await _dbHelper.fetchCategories(); // Fetch categories from DB
    String selectedCategory = categories.isNotEmpty ? categories[0] : '';

    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.white,
                  child: SizedBox(
                    width: 350,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Add New Dish",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF264653),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: "Dish Name",
                              prefixIcon: const Icon(
                                Icons.restaurant,
                                color: Color(0xFF2A9D8F),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Price",
                              prefixIcon: const Icon(
                                Icons.money,
                                color: Color(0xFFE76F51),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Dropdown for category selection
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            items:
                                categories.map((String category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                selectedCategory = newValue!;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Category",
                              prefixIcon: const Icon(
                                Icons.category,
                                color: Color(0xFFF4A261),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (nameController.text.isNotEmpty &&
                                      priceController.text.isNotEmpty) {
                                    double price = double.parse(
                                      priceController.text,
                                    );

                                    await _dbHelper.insertDish(
                                      nameController.text,
                                      price,
                                      selectedCategory,
                                    );

                                    setState(() {
                                      _loadDishes(); // Reload dishes from DB
                                    });

                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Add",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2A9D8F),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }*/

  @override
  Widget build(BuildContext context) {
    // Group dishes by category
    Map<String, List<Map<String, dynamic>>> groupedDishes = {};
    for (var dish in dishes) {
      if (!groupedDishes.containsKey(dish["category"])) {
        groupedDishes[dish["category"]] = [];
      }
      groupedDishes[dish["category"]]!.add(dish);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Dishes Management"),
        backgroundColor: const Color.fromARGB(255, 96, 140, 162),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1000, // Adjust table width to fit screen
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    groupedDishes.entries.map((entry) {
                      String category = entry.key;
                      List<Map<String, dynamic>> categoryDishes = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Heading
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              category, // Category Name
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 4, 4, 4),
                              ),
                            ),
                          ),
                          Table(
                            columnWidths: const {
                              0: FixedColumnWidth(50), // S.No
                              1: FlexColumnWidth(), // Dish Name (Auto Adjust)
                              2: FixedColumnWidth(140), // Price
                              3: FixedColumnWidth(170), // Category
                              4: FixedColumnWidth(
                                160,
                              ), // Actions (Reduced Width)
                            },
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
                            ),
                            children: [
                              // Table Header
                              const TableRow(
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 38, 50, 56),
                                ),
                                children: [
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        "S.No",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        "Dish Name",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        "Price",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        "Category",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        "Actions",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Table Rows for each dish in the category
                              ...categoryDishes.asMap().entries.map((entry) {
                                int categoryIndex =
                                    entry.key + 1; // Start numbering from 1
                                Map<String, dynamic> dish = entry.value;
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color:
                                        categoryIndex.isEven
                                            ? Colors.white
                                            : Colors.grey.shade100,
                                  ),
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text("$categoryIndex"),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(dish["name"]),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(dish["price"]),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(dish["category"]),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed:
                                                  () => _editDish(dish["sno"]),
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                "Edit",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
