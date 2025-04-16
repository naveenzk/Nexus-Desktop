import 'package:flutter/material.dart';
import 'home_page.dart';
import 'sidebar.dart';
import 'dashboard_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Widget _selectedPage = DishPage(); // Default page

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Bar
          Container(
            height: 60,
            color: Colors.blueGrey[900],
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "POS Restaurant",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => MyApp()),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      child: Text("Log Out"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  onMenuSelected: (page) {
                    setState(() {
                      _selectedPage = page;
                    });
                  },
                ),
                Expanded(
                  child: _selectedPage, // Only this area changes
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
