// lib/features/notification/widgets/notification_bell.dart
// ✅ COMPLETE FIX - No overflow

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/features/notification/screens/notifications_list_screen.dart';
import 'package:rojgarnext/features/notification/service/notification_service.dart';

class NotificationBell extends StatefulWidget {
  final VoidCallback? onNotificationClicked;
  final VoidCallback? onJobAlertClicked;
  final VoidCallback? onApplicationStatusClicked;

  const NotificationBell({
    super.key,
    this.onNotificationClicked,
    this.onJobAlertClicked,
    this.onApplicationStatusClicked,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  int unreadCount = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnreadCount();
    _setupNotificationListener();

    // ✅ FIXED: Increased polling interval from 1 second to 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUnreadCount();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadCount();
    }
  }

  void _setupNotificationListener() {
    NotificationService.addListener(_onNewNotification);
  }

  void _onNewNotification(Map<String, dynamic> notification) {
    if (kDebugMode) {
      debugPrint("🔔 New notification received: ${notification['type']}");
    }

    if (notification['type'] == 'refresh_count') {
      if (mounted) {
        setState(() {
          unreadCount = notification['unread_count'] ?? 0;
        });
      }
      return;
    }

    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            unreadCount = 0;
            _isLoading = false;
          });
        }
        return;
      }

      final count = await NotificationService.getUnreadCount();

      if (kDebugMode) {
        debugPrint("🔔 Bell unread count: $count");
      }

      if (mounted) {
        setState(() {
          unreadCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading unread count: $e");
      if (mounted) {
        setState(() {
          unreadCount = 0;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> refreshCount() async {
    await _loadUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    NotificationService.removeListener(_onNewNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNotifications = unreadCount > 0;

    // ✅ FIXED: Use Flexible and proper constraints to prevent overflow
    return Container(
      margin: const EdgeInsets.only(right: 8),
      constraints: const BoxConstraints(
        minWidth: 44,
        maxWidth: 44,
        minHeight: 44,
        maxHeight: 44,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsListScreen(
                    onJobAlertClicked: widget.onJobAlertClicked,
                    onApplicationStatusClicked:
                        widget.onApplicationStatusClicked,
                  ),
                ),
              );
              await refreshCount();
              if (widget.onNotificationClicked != null) {
                widget.onNotificationClicked!();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(25),
              ),
              child: Icon(
                hasNotifications
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: Colors.blue,
                size: 24,
              ),
            ),
          ),
          if (!_isLoading && hasNotifications)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}