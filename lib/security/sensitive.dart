import 'dart:typed_data';

/// In-memory wipe helpers for sensitive UI / RAM data.
///
/// Dart's garbage collector zeros reclaimed memory automatically on most
/// runtimes, but for defences-in-depth we **null-out** references and
/// explicitly zero large byte buffers the moment they are no longer needed so
/// they cannot linger in a heap-dump or debugger scan.
class SensitiveData {
  SensitiveData._();

  /// Zeroes [bytes] in place and releases the reference.
  static void wipeBytes(Uint8List? bytes) {
    if (bytes == null) return;
    bytes.fillRange(0, bytes.length, 0);
  }

  /// Disposes a [List] of byte buffers (e.g. per-message image cache).
  static void wipeBytesList(List<Uint8List?>? buffers) {
    if (buffers == null) return;
    for (final b in buffers) {
      wipeBytes(b);
    }
    buffers.clear();
  }
}
