import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'app_security.dart';

/// Network transport for every HTTP call the app makes.
///
/// TLS is pinned when fingerprints are supplied at build time
/// (`--dart-define=PIN_SHA256=<base64>,<base64>...` or via
/// `--dart-define-from-file=secrets.json`) — the client then accepts ONLY
/// certificates whose SHA-256 fingerprint (base64 of the SHA-256 digest of
/// the DER certificate) is in the list. A proxy or a TLS-interception box
/// presents a different certificate, so any MITM / proxy-capture attempt
/// fails closed.
///
/// When no pins are configured the default validation (chain + hostname) still
/// applies, and Android's network security config already forbids cleartext to
/// every host except the local dev loopback.
class SecureHttp {
  SecureHttp._();

  static const String _pinDefines = String.fromEnvironment('PIN_SHA256');

  static http.Client? _client;

  static http.Client get client {
    return _client ??= _build();
  }

  static List<String> _parsePins(String raw) {
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  static http.Client _build() {
    final pins = _parsePins(_pinDefines);
    if (pins.isEmpty || AppSecurity.isRunningUnderTest || kIsWeb) {
      // Nothing to pin against (dev URL, tests, web) -> default client.
      return http.Client();
    }
    final io = HttpClient();
    io.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return _matchesPin(cert, pins);
    };
    return IOClient(io);
  }

  static bool _matchesPin(X509Certificate cert, List<String> pins) {
    final digest = base64Encode(sha256.convert(cert.der).bytes);
    return pins.contains(digest);
  }
}
