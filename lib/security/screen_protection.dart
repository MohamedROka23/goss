import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_security.dart';

/// Blocks screenshots and screen-recording of the app's UI by marking the
/// window FLAG_SECURE on Android (the native WindowManager then refuses to
/// include the surface in any capture).
///
/// Disabled for dev/vendor builds built with `--dart-define=RASP_MODE=off`
/// (same switch that turns off freeRASP) so testers can capture screenshots.
/// Release/production builds always stay secured.
class ScreenProtection {
  ScreenProtection._();

  static const _channel = MethodChannel('goss/security');
  static bool _secured = false;

  static bool get _enabled {
    if (AppSecurity.isRunningUnderTest || kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    return const String.fromEnvironment('RASP_MODE') != 'off';
  }

  static Future<void> secure() async {
    if (_secured || !_enabled) return;
    try {
      // Until the platform answers, no screenshot can leak admin/customer data.
      await _channel.invokeMethod<void>('secureScreen');
      _secured = true;
    } catch (_) {}
  }
}
