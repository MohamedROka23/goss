import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Downsamples and re-encodes a photo so the encrypted payload stays well
/// below the Firestore 1 MiB document limit while keeping it legible on phones.
Future<Uint8List> compressForChat(List<int> bytes) async {
  final decoded = await _decode(Uint8List.fromList(bytes));
  if (decoded == null) {
    // Not a decodable image: send it through unmodified (will appear broken).
    return Uint8List.fromList(bytes);
  }
  const maxDim = 1200.0;
  var out = decoded;
  final largest = max(decoded.width, decoded.height).toDouble();
  if (largest > maxDim) {
    final scale = maxDim / largest;
    out = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
    );
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 72));
}

Future<img.Image?> _decode(Uint8List bytes) {
  try {
    return Future.value(img.decodeImage(bytes));
  } catch (_) {
    return Future.value(null);
  }
}