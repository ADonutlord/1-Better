// End-to-end verification of the E2EE chat flow against the live Supabase
// project, using the same crypto scheme as E2eeService:
//   X25519 ECDH + HKDF(conversation id) -> AES-256-GCM, payload "e1:<b64>".
//
// Run: dart run tool/e2ee_e2e_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const url = 'https://jkipantmyzhwyplmzfvh.supabase.co';
const anonKey = 'sb_publishable_AN_b61tGAq9HWZfWZ_WJRA_dvepbzX9';

const hkdfInfoPrefix = '1%better-e2ee-v1';
final x25519 = X25519();
final aes = AesGcm.with256bits();
final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
final random = Random.secure();

Future<dynamic> _req(String path, String method, String token,
    {Object? body}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse('$url$path');
    final r = await client.openUrl(method, uri);
    r.headers.set('apikey', anonKey);
    if (token.isNotEmpty) r.headers.set('Authorization', 'Bearer $token');
    r.headers.set('Content-Type', 'application/json');
    if (body != null) {
      r.write(jsonEncode(body));
    }
    final resp = await r.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: $text');
    }
    return text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
  } finally {
    client.close(force: true);
  }
}

Future<String> _signup(String email) async {
  final resp = await _req('/auth/v1/signup', 'POST', '',
      body: {
        'email': email,
        'password': 'testpass123',
        'data': {'display_name': email.split('@').first, 'profession': 'other'},
      });
  final token = resp['access_token'] as String?;
  if (token == null) throw Exception('No token for $email: $resp');
  return token;
}

Future<Uint8List> _uploadPubKey(String token, String userId) async {
  final pair = await x25519.newKeyPair();
  final priv = Uint8List.fromList(await pair.extractPrivateKeyBytes());
  final pub = await pair.extractPublicKey();
  await _req('/rest/v1/profiles?select=id&id=eq.$userId', 'PATCH', token,
      body: {'e2ee_public_key': base64Encode(pub.bytes)});
  return priv;
}

Future<SecretKey> _conversationKey(
    Uint8List myPriv, Uint8List peerPub, String convId) async {
  final myPair = await x25519.newKeyPairFromSeed(myPriv);
  final shared = await x25519.sharedSecretKey(
    keyPair: myPair,
    remotePublicKey: SimplePublicKey(peerPub, type: KeyPairType.x25519),
  );
  return hkdf.deriveKey(
    secretKey: shared,
    nonce: const <int>[],
    info: utf8.encode('$hkdfInfoPrefix|$convId'),
  );
}

Future<String> _encrypt(SecretKey key, String plain) async {
  final nonce = Uint8List(12);
  for (var i = 0; i < 12; i++) {
    nonce[i] = random.nextInt(256);
  }
  final box = await aes.encrypt(utf8.encode(plain), secretKey: key, nonce: nonce);
  final payload = BytesBuilder()
    ..add(nonce)
    ..add(box.cipherText)
    ..add(box.mac.bytes);
  return 'e1:${base64Encode(payload.toBytes())}';
}

Future<String> _decrypt(SecretKey key, String payload) async {
  final raw = base64Decode(payload.substring(3));
  final mac = Mac(raw.sublist(raw.length - 16));
  final cipher = raw.sublist(12, raw.length - 16);
  final clear = await aes.decrypt(
    SecretBox(cipher, nonce: raw.sublist(0, 12), mac: mac),
    secretKey: key,
  );
  return utf8.decode(clear);
}

Future<String> _pubKeyOf(String token, String userId) async {
  final rows = await _req(
      '/rest/v1/profiles?select=e2ee_public_key&id=eq.$userId', 'GET', token);
  return (rows as List).first['e2ee_public_key'] as String? ?? '';
}

Future<void> main() async {
  final emailA = 'e2ee.a${DateTime.now().millisecondsSinceEpoch}@gmail.com';
  final emailB = 'e2ee.b${DateTime.now().millisecondsSinceEpoch}@gmail.com';
  stdout.writeln('Creating users...');
  final tokenA = await _signup(emailA);
  final tokenB = await _signup(emailB);

  // User ids
  final meA = await _req('/auth/v1/user', 'GET', tokenA);
  final meB = await _req('/auth/v1/user', 'GET', tokenB);
  final idA = meA['id'] as String;
  final idB = meB['id'] as String;
  stdout.writeln('A=$idA B=$idB');

  // Upload public keys
  final privA = await _uploadPubKey(tokenA, idA);
  final privB = await _uploadPubKey(tokenB, idB);

  // Verify cross-read of public keys (RLS: authenticated can select all)
  final pubA = await _pubKeyOf(tokenB, idA);
  final pubB = await _pubKeyOf(tokenA, idB);
  stdout.writeln('pubA readable by B: ${pubA.isNotEmpty}');
  stdout.writeln('pubB readable by A: ${pubB.isNotEmpty}');

  // Create a conversation via the real RPC flow: A starts waiting, B starts
  // waiting, then B's find_match pairs them.
  final convA = await _req('/rest/v1/rpc/start_conversation', 'POST', tokenA);
  await _req('/rest/v1/rpc/start_conversation', 'POST', tokenB);
  final match = await _req('/rest/v1/rpc/find_match', 'POST', tokenB);
  final convId = (match is Map<String, dynamic>)
      ? match['conversation_id'] as String
      : (match as List).first['conversation_id'] as String;
  stdout.writeln('conversation $convId');

  // A derives key from A's priv + B's pub; B derives from B's priv + A's pub.
  final keyA = await _conversationKey(privA, base64Decode(pubB), convId);
  final keyB = await _conversationKey(privB, base64Decode(pubA), convId);
  final bA = await keyA.extractBytes();
  final bB = await keyB.extractBytes();
  stdout.writeln('keys match: ${base64Encode(bA) == base64Encode(bB)}');

  // A encrypts & sends; B reads (as plain REST) and decrypts.
  const secret = 'You are doing great today. 🌱 Keep the streak!';
  final payload = await _encrypt(keyA, secret);
  await _req('/rest/v1/messages?select=id', 'POST', tokenA,
      body: {
        'conversation_id': convId,
        'sender_id': idA,
        'message': payload,
        'message_type': 'text',
      });
  stdout.writeln('stored payload is encrypted: ${payload.startsWith('e1:')}');

  final rows = await _req(
      '/rest/v1/messages?select=message&conversation_id=eq.$convId', 'GET', tokenB);
  final stored = (rows as List).last['message'] as String;
  final clear = await _decrypt(keyB, stored);
  stdout.writeln('B decrypted: ${clear == secret}');

  stdout.writeln(clear == secret && base64Encode(bA) == base64Encode(bB)
      ? '\nE2EE E2E PASS ✓'
      : '\nE2EE E2E FAIL ✗');
}
