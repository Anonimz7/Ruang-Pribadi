import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// ═══════════════════════════════════════════════════════
/// PLANTUML CLIENT — render PlantUML asli via server (PNG)
/// ═══════════════════════════════════════════════════════
/// Kode PlantUML di-compress (raw deflate) lalu di-encode
/// base64 charset khusus PlantUML, kemudian di-request ke
/// `<server>/png/<encoded>`. Layout & fitur = PlantUML asli
/// (graphviz): rapi, warna per-stereotype, note, semua tipe.
///
/// Server default = publik plantuml.com. Ganti
/// [kPlantumlServerDefault] kalau pakai server sendiri.
/// ═══════════════════════════════════════════════════════
const String kPlantumlServerDefault = 'https://www.plantuml.com/plantuml';

/// Charset base64 khusus PlantUML (URL-safe, tanpa + / =).
const String _alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_';

String _encode64(Uint8List data) {
  final sb = StringBuffer();
  var i = 0;
  final n = data.length;
  while (i < n) {
    var c1 = data[i++] & 0xff;
    sb.write(_alphabet[c1 >> 2]);
    c1 = (c1 & 0x03) << 4;
    if (i >= n) {
      sb.write(_alphabet[c1]);
      break;
    }
    var c2 = data[i++] & 0xff;
    c1 |= c2 >> 4;
    sb.write(_alphabet[c1]);
    c1 = (c2 & 0x0f) << 2;
    if (i >= n) {
      sb.write(_alphabet[c1]);
      break;
    }
    c2 = data[i++] & 0xff;
    c1 |= c2 >> 6;
    sb.write(_alphabet[c1]);
    sb.write(_alphabet[c2 & 0x3f]);
  }
  return sb.toString();
}

/// Encode sumber PlantUML ke bentuk URL (raw deflate + base64 PlantUML).
String plantumlEncode(String source) {
  final bytes = utf8.encode(source);
  final compressed = ZLibCodec(level: 1, raw: true).encode(bytes);
  return _encode64(Uint8List.fromList(compressed));
}

class PlantumlClient {
  final http.Client _http;
  final String server;

  PlantumlClient({http.Client? httpClient, this.server = kPlantumlServerDefault})
      : _http = httpClient ?? http.Client();

  /// Render sumber PlantUML menjadi byte PNG.
  Future<Uint8List> fetchPng(String source) async {
    final uri = Uri.parse('$server/png/${plantumlEncode(source)}');
    final res =
        await _http.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      final body = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw Exception('PlantUML server ${res.statusCode}: $body');
    }
    return res.bodyBytes;
  }
}