// lib/features/payment/razorpay_web_service.dart
// ✅ COMPLETE WEB VERSION - Works only on Web (dart.library.js)
// ✅ FIXED: Robust SDK loading with better error handling

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
// ✅ Ye import Android build me ignore ho jayega
import 'dart:js' if (dart.library.js) 'dart:js' as js;
// ✅ Ye import Android build me ignore ho jayega
import 'dart:js_util' if (dart.library.js) 'dart:js_util' as js_util;

class RazorpayWebService {
  static RazorpayWebService? _instance;
  bool _isSDKLoaded = false;
  bool _isPaymentOpen = false;
  Completer<bool>? _sdkLoadCompleter;

  RazorpayWebService._internal();

  static RazorpayWebService get instance {
    _instance ??= RazorpayWebService._internal();
    return _instance!;
  }

  Future<bool> _loadRazorpaySDK() async {
    if (!kIsWeb) {
      return false;
    }

    // If SDK is already loaded, return true
    if (_isSDKLoaded) {
      return true;
    }

    // If SDK is currently loading, wait for it
    if (_sdkLoadCompleter != null) {
      return _sdkLoadCompleter!.future;
    }

    _sdkLoadCompleter = Completer<bool>();

    try {
      // Check if Razorpay is already loaded
      try {
        final existing = js.context.callMethod('eval', ['typeof Razorpay']);
        if (existing != 'undefined') {
          _isSDKLoaded = true;
          _sdkLoadCompleter!.complete(true);
          return true;
        }
      } catch (e) {
        // Ignore
      }

      // Create script element
      final script = js.context.callMethod('document.createElement', ['script']);
      script['src'] = 'https://checkout.razorpay.com/v1/checkout.js';
      script['async'] = true;
      script['defer'] = true;

      // Create a promise that resolves when the script loads
      script['onload'] = js.allowInterop(() {
        _isSDKLoaded = true;
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.complete(true);
        }
      });

      script['onerror'] = js.allowInterop((error) {
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.complete(false);
        }
      });

      // Append script to head or body
      final head = js.context.callMethod('document.getElementsByTagName', ['head']);
      if (head != null && head.length > 0) {
        head[0].callMethod('appendChild', [script]);
      } else {
        final body = js.context.callMethod('document.getElementsByTagName', ['body']);
        if (body != null && body.length > 0) {
          body[0].callMethod('appendChild', [script]);
        } else {
          _sdkLoadCompleter!.complete(false);
          return false;
        }
      }

      // Wait for the script to load with a timeout
      await Future.any([
        _sdkLoadCompleter!.future,
        Future.delayed(const Duration(seconds: 10), () => false),
      ]);

      // Double-check if Razorpay is now available
      try {
        final check = js.context.callMethod('eval', ['typeof Razorpay']);
        if (check != 'undefined') {
          _isSDKLoaded = true;
          if (!_sdkLoadCompleter!.isCompleted) {
            _sdkLoadCompleter!.complete(true);
          }
          return true;
        }
      } catch (e) {
        // Ignore
      }

      return false;
    } catch (e) {
      if (!_sdkLoadCompleter!.isCompleted) {
        _sdkLoadCompleter!.complete(false);
      }
      return false;
    } finally {
      _sdkLoadCompleter = null;
    }
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
    if (!kIsWeb) {
      onError("Payment service not available on this platform.");
      return;
    }

    final sdkLoaded = await _loadRazorpaySDK();
    if (!sdkLoaded) {
      onError("Payment service not available. Please refresh and try again.");
      return;
    }

    if (_isPaymentOpen) {
      onError("Payment window is already open");
      return;
    }

    try {
      final options = {
        'key': keyId,
        'amount': amount * 100,
        'currency': 'INR',
        'name': 'RojgarNext',
        'description': 'Payment for service',
        'order_id': orderId,
        'prefill': {
          'contact': userMobile.isNotEmpty ? userMobile : '9999999999',
          'email': userEmail.isNotEmpty ? userEmail : 'user@example.com',
          'name': userName.isNotEmpty ? userName : 'User',
        },
        'theme': {
          'color': '#1E3A8A',
        },
        'modal': {
          'ondismiss': js.allowInterop(() {
            _isPaymentOpen = false;
            onError('Payment cancelled by user');
          }),
        },
        'handler': js.allowInterop((response) {
          _isPaymentOpen = false;
          final paymentId = response['razorpay_payment_id']?.toString();
          final orderIdResp = response['razorpay_order_id']?.toString();
          final signature = response['razorpay_signature']?.toString();

          if (paymentId == null || paymentId.isEmpty) {
            onError("Payment verification failed.");
            return;
          }

          onSuccess({
            'razorpay_payment_id': paymentId,
            'razorpay_order_id': orderIdResp ?? orderId,
            'razorpay_signature': signature,
            'payment_id': paymentId,
          });
        }),
      };

      final razorpayConstructor = js.context['Razorpay'];
      if (razorpayConstructor == null) {
        onError('Payment service not available.');
        return;
      }

      final jsOptions = js.JsObject.jsify(options);
      final razorpay = js.JsObject(razorpayConstructor, [jsOptions]);

      _isPaymentOpen = true;
      razorpay.callMethod('open');

    } catch (e) {
      _isPaymentOpen = false;
      onError("Failed to open payment: ${e.toString()}");
    }
  }

  void dispose() {
    _isSDKLoaded = false;
    _isPaymentOpen = false;
    _sdkLoadCompleter = null;
  }
}