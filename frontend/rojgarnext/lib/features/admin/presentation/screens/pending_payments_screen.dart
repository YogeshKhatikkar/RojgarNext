// lib/features/admin/presentation/screens/pending_payments_screen.dart
import 'package:flutter/material.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/widgets/file_viewer_screen.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  List<dynamic> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    try {
      final res = await DioClient.dio.get("/admin/pending-payments");
      if (!mounted) return;
      setState(() {
        _payments = res.data["payments"];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to load: $e", isError: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _verify(String paymentId, bool approve, {String? notes}) async {
    try {
      final res = await DioClient.dio.post(
        "/admin/verify-payment/$paymentId",
        queryParameters: {
          "action": approve ? "approve" : "reject",
          "notes": notes ?? "",
        },
      );
      if (!mounted) return;
      showMessage(context, res.data["message"]);
      await _fetchPending(); // refresh list
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Verification failed: $e", isError: true);
    }
  }

  void _showScreenshot(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileViewerScreen(url: url, title: "Payment Screenshot"),
      ),
    );
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rejection Reason"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter reason"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_payments.isEmpty) {
      return const Center(child: Text("No pending verifications"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Payment Verifications"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length,
        itemBuilder: (_, i) {
          final p = _payments[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text("${p["user_email"]} - ₹${p["amount"]}"),
              subtitle: Text("Job: ${p["job_title"]}"),
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text("Transaction ID: ${p["transaction_id"]}"),
                  subtitle: Text("Date: ${p["transaction_date"]}"),
                ),
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text("Screenshot"),
                  trailing: ElevatedButton(
                    onPressed: () => _showScreenshot(p["screenshot_url"]),
                    child: const Text("View"),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _verify(p["_id"], true),
                        icon: const Icon(Icons.check),
                        label: const Text("Approve"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final notes = await _showRejectDialog();
                          if (notes != null) {
                            await _verify(p["_id"], false, notes: notes);
                          }
                        },
                        icon: const Icon(Icons.close),
                        label: const Text("Reject"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
