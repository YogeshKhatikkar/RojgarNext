// lib/features/payment/razorpay_service.dart
// ✅ PLATFORM-AWARE - Android me web service import nahi hoga

import 'package:flutter/foundation.dart' show kIsWeb;

// Web implementation - Sirf Web par import hoga
import 'razorpay_web_service.dart'
    if (dart.library.js) 'razorpay_web_service.dart'
    as web;

// Mobile implementation - Mobile par import hoga
import 'razorpay_mobile_service.dart'
    if (dart.library.html) 'razorpay_mobile_service.dart'
    as mobile;

class RazorpayService {
  static RazorpayService? _instance;

  RazorpayService._internal();

  static RazorpayService get instance {
    _instance ??= RazorpayService._internal();
    return _instance!;
  }

  Future<void> initiatePayment({
    required int amount,
    required String orderId,
    required String keyId,
    required String userEmail,
    required String userName,
    required String userMobile,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onError,
    required Function() onExternalWallet,
  }) async {
    if (kIsWeb) {
      // ✅ Web platform ke liye web service
      await web.RazorpayWebService.instance.initiatePayment(
        amount: amount,
        orderId: orderId,
        keyId: keyId,
        userEmail: userEmail,
        userName: userName,
        userMobile: userMobile,
        onSuccess: onSuccess,
        onError: onError,
        onExternalWallet: onExternalWallet,
      );
      return;
    }

    // ✅ Mobile platform ke liye mobile service
    await mobile.RazorpayMobileService.instance.initiatePayment(
      amount: amount,
      orderId: orderId,
      keyId: keyId,
      userEmail: userEmail,
      userName: userName,
      userMobile: userMobile,
      onSuccess: onSuccess,
      onError: onError,
      onExternalWallet: onExternalWallet,
    );
  }

  void dispose() {
    if (kIsWeb) {
      try {
        web.RazorpayWebService.instance.dispose();
      } catch (e) {
        // ignore
      }
    } else {
      mobile.RazorpayMobileService.instance.dispose();
    }
  }
}