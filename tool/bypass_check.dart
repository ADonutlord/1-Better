// Verify a suspended user cannot clear their own suspension via the API.
import 'dart:convert';
import 'dart:io';

const url = 'https://jkipantmyzhwyplmzfvh.supabase.co';
const anonKey = 'sb_publishable_AN_b61tGAq9HWZfWZ_WJRA_dvepbzX9';

Future<dynamic> _req(String path, String method, String token,
    {Object? body, bool allowError = false}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse('$url$path');
    final r = await client.openUrl(method, uri);
    r.headers.set('apikey', anonKey);
    if (token.isNotEmpty) r.headers.set('Authorization', 'Bearer $token');
    r.headers.set('Content-Type', 'application/json');
    if (body != null) r.write(jsonEncode(body));
    final resp = await r.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 300) {
      if (allowError) return text;
      throw Exception('HTTP ${resp.statusCode}: $text');
    }
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
  } finally {
    client.close(force: true);
  }
}

Future<void> main() async {
  final adminLogin = await _req('/auth/v1/token?grant_type=password', 'POST', '',
      body: {'email': 'e2e3.test.1better@gmail.com', 'password': 'testpass123'},
      allowError: true);
  stdout.writeln('admin(?) login: $adminLogin');
}
