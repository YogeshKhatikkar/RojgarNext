// lib/features/admin/presentation/screens/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // Try superadmin endpoint first, fallback to admin
      try {
        final res = await DioClient.dio.get('/superadmin/users');
        if (mounted) {
          setState(() => users = res.data['users'] ?? []);
        }
      } catch (e) {
        // If superadmin fails, try admin endpoint
        final res = await DioClient.dio.get('/admin/users');
        if (mounted) {
          setState(() => users = res.data['users'] ?? []);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to load users: $e", isError: true);
        setState(() => users = []);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    try {
      await DioClient.dio.put(
        '/admin/users/$userId/status',
        data: {'is_active': !isActive},
      );
      if (mounted) {
        _fetchUsers();
        showMessage(context, "User status updated");
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error updating status: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text("No users found"))
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(u['name']?.substring(0, 1) ?? 'U'),
                    ),
                    title: Text(u['name'] ?? ''),
                    subtitle: Text(u['email'] ?? ''),
                    trailing: Switch(
                      value: u['is_active'] ?? true,
                      onChanged: (_) =>
                          _toggleUserStatus(u['_id'], u['is_active']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
