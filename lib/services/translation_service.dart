import 'dart:convert';
import 'dart:io';

/// Free Google Translate bridge (Arabic -> English) used to auto-fill the
/// English product name and description in the quotes form.
class TranslationService {
  static Future<String> arToEn(String text) async {
    final q = text.trim();
    if (q.isEmpty) return '';
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('https://translate.googleapis.com/translate_a/single').replace(
        queryParameters: {
          'client': 'gtx',
          'sl': 'ar',
          'tl': 'en',
          'dt': 't',
          'q': q,
        },
      );
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final data = json.decode(body) as List;
      final segs = (data.isNotEmpty ? data.first : null) as List? ?? [];
      final out = segs.map((s) => (s is List && s.isNotEmpty) ? '${s.first}' : '').join();
      return out.trim().isEmpty ? q : out.trim();
    } catch (_) {
      return q;
    }
  }
}