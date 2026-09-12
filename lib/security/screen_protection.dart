import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_security.dart';

/// Blocks screenshots and screen-recording of the app's UI by marking the
/// window FLAG_SECURE on Android (the native WindowManager then refuses to
/// include the surface in any capture).
class ScreenProtection {
  ScreenProtection._();

  static const _channel = MethodChannel('goss/security');
  static bool _secured = false;

  static Future<void> secure() async {
    if (_secured) return;
    if (AppSecurity.isRunningUnderTest || kIsWeb || !Platform.isAndroid) return;
    try {
      // Until the platform answers, no screenshot can leak admin/customer data.
      await _channel.invokeMethod<void>('secureScreen');
      _secured = true;
    } catch (_) {}
  }
}
