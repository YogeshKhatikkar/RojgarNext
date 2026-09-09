// lib/features/user/presentation/screens/user_support_screen.dart
// COMPLETE SUPPORT SCREEN WITH EMAIL SENDING AND CUSTOMER CARE NUMBERS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ADD THIS FOR CLIPBOARD
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _isSubmitting = false;
  String? _userEmail;
  String? _userName;

  // Customer care numbers
  final List<Map<String, String>> _customerCareNumbers = [
    {'number': '7869986602', 'type': 'Primary', 'icon': '📞'},
    {'number': '1800125348', 'type': 'Toll-Free', 'icon': '📱'},
  ];

  // Support email (default recipient)
  static const String _supportEmail = "yhk.capital@gmail.com";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final email = await SecureStorage.getEmail();
      final name = await SecureStorage.getName();
      if (mounted) {
        setState(() {
          _userEmail = email ?? '';
          _userName = name ?? '';
        });
      }
      debugPrint("📧 Support - User Email: $_userEmail, Name: $_userName");
    } catch (e) {
      debugPrint("❌ Error loading user info: $e");
    }
  }

  Future<void> _sendSupportMessage() async {
    final message = _messageController.text.trim();
    final subject = _subjectController.text.trim();

    if (message.isEmpty) {
      showMessage(context, "Please enter your message", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        throw Exception("Please login to send support message");
      }

      // Prepare email data
      final emailData = {
        'to': _supportEmail,
        'from_email': _userEmail,
        'from_name': _userName,
        'subject': subject.isNotEmpty
            ? subject
            : "Support Request from RojgarNext User",
        'message': message,
        'user_email': _userEmail,
        'user_name': _userName,
      };

      debugPrint("📧 Sending support email to: $_supportEmail");
      debugPrint("   From: $_userEmail");
      debugPrint(
          "   Subject: ${subject.isNotEmpty ? subject : 'Support Request'}");
      debugPrint("   Message length: ${message.length}");

      // Send via backend API
      final response = await DioClient.dio.post(
        '/support/send-email',
        data: emailData,
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "✅ Your message has been sent to support team! We'll respond within 24-48 hours.",
        );
        _messageController.clear();
        _subjectController.clear();
      } else {
        throw Exception(response.data['message'] ?? "Failed to send message");
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Support email error: $e");

      // Fallback: Show email composition
      _showEmailCompositionFallback(message, subject);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Fallback method to open email client
  Future<void> _showEmailCompositionFallback(
      String message, String subject) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _buildEmailQuery(message, subject),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (mounted) {
        showMessage(
          context,
          "Opening email client. Please send your message to $_supportEmail",
        );
      }
    } else {
      if (mounted) {
        showMessage(
          context,
          "Could not open email client. Please email your message to: $_supportEmail",
          isError: true,
        );
      }
    }
  }

  String _buildEmailQuery(String message, String subject) {
    final params = <String, String>{
      'subject':
          subject.isNotEmpty ? subject : "Support Request from RojgarNext",
      'body': '''
User Name: ${_userName ?? 'Not provided'}
User Email: ${_userEmail ?? 'Not provided'}

Message: 
$message
---
This message was sent from RojgarNext App
      ''',
    };
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        showMessage(context, "Could not make call to $phoneNumber",
            isError: true);
      }
    }
  }

  Future<void> _sendWhatsAppMessage(String phoneNumber) async {
    // Remove any non-digit characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanNumber,
      queryParameters: {'text': 'Hello, I need support from RojgarNext.'},
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showMessage(context, "WhatsApp is not installed on this device",
            isError: true);
      }
    }
  }

  void _copyEmailToClipboard() {
    Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (mounted) {
      showMessage(context, "Email address copied to clipboard!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Support Center"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserInfo,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== USER INFO CARD ====================
            _buildUserInfoCard(),
            const SizedBox(height: 20),

            // ==================== SEND MESSAGE SECTION ====================
            _buildSendMessageSection(),
            const SizedBox(height: 24),

            // ==================== CUSTOMER CARE SECTION ====================
            _buildCustomerCareSection(),
            const SizedBox(height: 24),

            // ==================== ALTERNATIVE CONTACT SECTION ====================
            _buildAlternativeContactSection(),
            const SizedBox(height: 24),

            // ==================== FAQ HINT ====================
            _buildFaqHint(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "How can we help you?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName != null && _userName!.isNotEmpty
                      ? "Welcome, ${_userName!.split(' ').first}!"
                      : "We're here to assist you",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
                if (_userEmail != null && _userEmail!.isNotEmpty)
                  Text(
                    _userEmail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(179),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMessageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.email, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                "Send Message to Support",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Subject Field
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: "Subject (Optional)",
              hintText: "e.g., Application Issue, Technical Problem",
              prefixIcon: const Icon(Icons.subject, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message Field
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: "Your Message *",
              hintText: "Describe your issue or question in detail...",
              prefixIcon: const Icon(Icons.message, size: 20),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll respond to your registered email: ${_userEmail ?? 'your email'}",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _sendSupportMessage,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 20),
              label: Text(
                _isSubmitting ? "Sending..." : "Send Message",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCareSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_in_talk,
                    color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                "Customer Care",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ..._customerCareNumbers.map((contact) => _buildContactCard(
                icon: contact['icon']!,
                number: contact['number']!,
                label: contact['type']!,
                onCall: () => _makePhoneCall(contact['number']!),
                onWhatsApp: () => _sendWhatsAppMessage(contact['number']!),
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Support Hours: Mon-Sat, 10:00 AM - 6:00 PM",
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required String icon,
    required String number,
    required String label,
    required VoidCallback onCall,
    required VoidCallback onWhatsApp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Call Button
              InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call, color: Colors.green, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // WhatsApp Button
              InkWell(
                onTap: onWhatsApp,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat,
                      color: Color(0xFF25D366), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.alternate_email,
                    color: Colors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                "Alternative Contact",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Email Contact
          InkWell(
            onTap: _copyEmailToClipboard,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Email Support",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _supportEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Copy",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Quick FAQ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "• How to apply for jobs?\n"
                  "• How to update profile?\n"
                  "• Payment related issues?\n"
                  "Contact us for any assistance!",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
