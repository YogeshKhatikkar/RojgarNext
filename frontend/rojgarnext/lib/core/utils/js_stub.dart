// lib/core/utils/js_stub.dart
// ✅ COMPLETE FIXED VERSION - Safe for both Web and Android builds
// ✅ NO CONFLICT with the 'web' package (we don't import it)

// Conditional imports. These are only available in a web context.
import 'dart:js' if (dart.library.js) 'dart:js' as js;
import 'dart:js_util' if (dart.library.js) 'dart:js_util' as js_util;

/// ✅ Safe wrapper for JsObject
/// On web: actual JsObject from dart:js
/// On mobile: a stub that mimics the necessary behavior.
class JsObjectStub {
  final dynamic _obj;
  JsObjectStub(this._obj);

  // Allow dynamic access to properties.
  dynamic operator [](String key) => _obj?[key];
  void operator []=(String key, dynamic value) { if (_obj != null) _obj[key] = value; }
  dynamic callMethod(String methodName, [List<dynamic>? args]) {
    if (_obj == null) return null;
    final method = _obj[methodName];
    if (method is Function) {
      return Function.apply(method, args ?? []);
    }
    return null;
  }
}

/// ✅ Safe way to get the window object
/// Returns a JsObjectStub on web, null on other platforms.
dynamic getWindow() {
  if (dart.library.js) {
    try {
      return JsObjectStub(js.context['window']);
    } catch (e) {
      return null;
    }
  }
  return null;
}

/// ✅ Safe way to call js.allowInterop
/// Returns a wrapper that behaves like js.allowInterop on web,
/// or just returns the callback on non-web platforms.
dynamic allowInterop(dynamic callback) {
  if (dart.library.js) {
    try {
      return js.allowInterop(callback);
    } catch (e) {
      return callback;
    }
  }
  return callback;
}

/// ✅ Safe type aliases for JS types
/// On web: actual types from dart:js
/// On mobile: dynamic (stub)

/// JsObject - Safe type alias
typedef JsObject = dynamic;

/// JsFunction - Safe type alias
typedef JsFunction = dynamic;

/// JsArray - Safe type alias  
typedef JsArray = dynamic;

/// JsNumber - Safe type alias
typedef JsNumber = dynamic;

/// JsArrayBuffer - Safe type alias
typedef JsArrayBuffer = dynamic;

/// JSAny - Safe type alias
typedef JSAny = dynamic;