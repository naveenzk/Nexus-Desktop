import 'package:flutter/material.dart';

class MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget page;
  final Function(Widget) onTap;

  const MenuTile({
    super.key,
    required this.title,
    required this.icon,
    required this.page,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        onTap(page);
      },
    );
  }
}
