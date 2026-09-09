// lib/features/payment/razorpay_mobile_service.dart
// ✅ ANDROID ONLY - Uses razorpay_flutter SDK

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayMobileService {
  static RazorpayMobileService? _instance;
  Razorpay? _razorpay;
  bool _isPaymentOpen = false;

  RazorpayMobileService._internal();

  static RazorpayMobileService get instance {
    _instance ??= RazorpayMobileService._internal();
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
      onError("Mobile service called on web platform");
      return;
    }

    try {
      if (_razorpay == null) {
        _razorpay = Razorpay();
      }

      _razorpay!.clear();

      // ✅ Payment Success
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        _isPaymentOpen = false;
        if (response.paymentId == null || response.paymentId!.isEmpty) {
          onError("Payment verification failed.");
          return;
        }
        onSuccess({
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId ?? orderId,
          'razorpay_signature': response.signature,
        });
      });

      // ✅ Payment Error
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        _isPaymentOpen = false;
        onError(response.message ?? 'Payment failed. Please try again.');
      });

      // ✅ External Wallet
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
        onExternalWallet();
      });

      final options = {
        'key': keyId,
        'amount': amount * 100,
        'name': 'RojgarNext',
        'description': 'Payment for service',
        'order_id': orderId,
        'prefill': {
          'contact': userMobile.isNotEmpty ? userMobile : '9999999999',
          'email': userEmail.isNotEmpty ? userEmail : 'user@example.com',
          'name': userName.isNotEmpty ? userName : 'User',
        },
        'theme': {'color': '#1E3A8A'},
      };

      _isPaymentOpen = true;
      _razorpay!.open(options);

    } catch (e) {
      _isPaymentOpen = false;
      onError("Failed to open payment: ${e.toString()}");
    }
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _isPaymentOpen = false;
  }
}