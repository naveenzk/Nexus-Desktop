import 'package:flutter/material.dart';
import 'package:nexus_desktop/home_page.dart';
import 'dashboard_page.dart';
import 'total_sales_page.dart';
import 'reset_page.dart';

class Sidebar extends StatelessWidget {
  final Function(Widget) onMenuSelected;

  const Sidebar({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 96, 140, 162),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // User Profile
          // User Profile
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white, // Optional: Background color
            child: Icon(
              Icons.fastfood, // Food-related icon
              size: 40,
              color: Colors.blueGrey,
            ),
          ),

          const SizedBox(height: 10),
          const Text(
            "Bismillah Restaurant",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Menu Items
          _buildMenuItem(
            Icons.dashboard,
            'Dashboard',
            const DishPage(),
            context,
          ),
          _buildMenuItem(
            Icons.bar_chart,
            'Total Sales',
            const TotalSalesPage(),
            context,
          ),
          _buildMenuItem(
            Icons.settings_backup_restore,
            'Reset',
            const ResetPage(),
            context,
          ),

          const SizedBox(height: 20), // Space for Image

          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: AssetImage("assets/trust_nexus_desktop_logo.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Powered By: Trust nexus_desktop
          const Column(
            children: [
              Text(
                "Powered By: Trust Nexus",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Contact: 0330-8184136",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const Spacer(),

          // HomeScreen Button (Back Navigation)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: GestureDetector(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                  (route) => false, // Remove all previous routes
                );
              },
              child: Container(
                width: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "HomeScreen",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to Build Menu Item
  Widget _buildMenuItem(
    IconData icon,
    String title,
    Widget page,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () => onMenuSelected(page),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
