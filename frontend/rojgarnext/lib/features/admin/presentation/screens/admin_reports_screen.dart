// lib/features/admin/presentation/screens/admin_reports_screen.dart
import 'package:flutter/material.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 100, color: Colors.blueAccent),
          SizedBox(height: 24),
          Text(
            "Reports & Analytics",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            "Total Users, Applications, Job Trends",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          // You can integrate charts using fl_chart later
        ],
      ),
    );
  }
}
