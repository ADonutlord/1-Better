// Reproduce the conversation completion flow against the live DB:
// start_conversation -> find_match -> end_conversation -> check daily_progress.
import 'dart:convert';
import 'dart:io';

const url = 'https://jkipantmyzhwyplmzfvh.supabase.co';
const anonKey = 'sb_publishable_AN_b61tGAq9HWZfWZ_WJRA_dvepbzX9';

Future<dynamic> _req(String path, String method, String token, {Object? body}) async {
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
    if (resp.statusCode >= 300) throw Exception('HTTP ${resp.statusCode}: $text');
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
  } finally {
    client.close(force: true);
  }
}

Future<String> _signup(String email) async {
  final resp = await _req('/auth/v1/signup', 'POST', '', body: {
    'email': email,
    'password': 'testpass123',
    'data': {'display_name': email.split('@').first, 'profession': 'student'},
  });
  final token = resp['access_token'] as String?;
  if (token == null) throw Exception('No token: $resp');
  return token;
}

Future<void> main() async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final tokenA = await _signup('flow.a$stamp@gmail.com');
  final tokenB = await _signup('flow.b$stamp@gmail.com');

  stdout.writeln('A: start_conversation -> ${await _req('/rest/v1/rpc/start_conversation', 'POST', tokenA)}');
  stdout.writeln('B: start_conversation -> ${await _req('/rest/v1/rpc/start_conversation', 'POST', tokenB)}');

  final match = await _req('/rest/v1/rpc/find_match', 'POST', tokenB);
  stdout.writeln('B find_match -> $match');
  final convId = (match as Map<String, dynamic>)['conversation_id'];

  stdout.writeln('A end_conversation ->');
  try {
    final ended = await _req('/rest/v1/rpc/end_conversation', 'POST', tokenA, body: {'p_conversation_id': convId});
    stdout.writeln('  result: $ended');
  } catch (e) {
    stdout.writeln('  ERROR: $e');
  }

  final meA = await _req('/auth/v1/user', 'GET', tokenA);
  final idA = meA['id'] as String;
  final dp = await _req('/rest/v1/daily_progress?select=*&user_id=eq.$idA', 'GET', tokenA);
  stdout.writeln('A daily_progress -> $dp');

  final xp = await _req('/rest/v1/xp_events?select=*&user_id=eq.$idA&event_type=eq.chat_complete', 'GET', tokenA);
  stdout.writeln('A chat_complete xp -> $xp');
}
