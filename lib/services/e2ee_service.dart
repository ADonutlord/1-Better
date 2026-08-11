import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side end-to-end encryption for 1:1 chat messages.
///
/// Scheme:
///  * Each user has an X25519 keypair. The public key is uploaded to
///    `profiles.e2ee_public_key`; the private key never leaves the device
///    (stored in local preferences).
///  * For a conversation, both participants derive the same shared secret
///    via ECDH (their private key + the peer's public key).
///  * The conversation key is HKDF-SHA256(shared secret, info=conversation id).
///  * User text messages are encrypted with AES-256-GCM (random 12-byte nonce)
///    and stored as `e1:<base64(nonce | ciphertext | mac)>`.
///  * Server-generated `system`/`action_recommendation` messages are not
///    encryptable (the server writes them) and stay plaintext.
///
/// If the peer has not uploaded a public key yet (older clients), messages
/// fall back to plaintext so existing accounts keep working.
class E2eeService {
  E2eeService._();

  static final E2eeService instance = E2eeService._();

  static const String _payloadPrefix = 'e1:';
  static const String _privKeyPrefPrefix = 'e2ee_priv_';
  static const String _hkdfInfoPrefix = '1%better-e2ee-v1';

  final X25519 _x25519 = X25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Random _random = Random.secure();

  /// Private key bytes of the signed-in user, cached after unlock.
  Uint8List? _privateKey;

  /// Cached conversation keys keyed by conversation id.
  final Map<String, SecretKey> _convKeys = {};

  SupabaseClient get _client => SupabaseService.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------
  // Key management
  // ---------------------------------------------------------------------

  /// Loads the current user's private key from local storage, generating a
  /// fresh keypair (and uploading its public key) the first time.
  Future<void> ensureKeys() async {
    final userId = _userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_privKeyPrefPrefix + userId);
    if (stored != null) {
      _privateKey = base64Decode(stored);
    } else {
      final pair = await _x25519.newKeyPair();
      final priv = Uint8List.fromList(await pair.extractPrivateKeyBytes());
      _privateKey = priv;
      await prefs.setString(_privKeyPrefPrefix + userId, base64Encode(priv));
    }
    // Make sure our public key is published so peers can encrypt to us.
    await _uploadPublicKey();
  }

  Future<void> _uploadPublicKey() async {
    final userId = _userId;
    final priv = _privateKey;
    if (userId == null || priv == null) return;
    final pair = await _x25519.newKeyPairFromSeed(priv);
    final pub = await pair.extractPublicKey();
    await _client
        .from('profiles')
        .update({'e2ee_public_key': base64Encode(pub.bytes)})
        .eq('id', userId);
  }

  /// The peer's public key as bytes, or null when the peer has no key yet.
  Future<Uint8List?> _peerPublicKey(String peerId) async {
    final row = await _client
        .from('profiles')
        .select('e2ee_public_key')
        .eq('id', peerId)
        .maybeSingle();
    final b64 = row?['e2ee_public_key'] as String?;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Public key of the *other* participant in a conversation.
  Future<Uint8List?> _peerPublicKeyForConversation(String conversationId) async {
    final myId = _userId;
    if (myId == null) return null;
    final rows = await _client
        .from('conversation_participants')
        .select('user_id')
        .eq('conversation_id', conversationId);
    for (final r in rows) {
      final id = r['user_id'] as String?;
      if (id != null && id != myId) {
        return _peerPublicKey(id);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Conversation key
  // ---------------------------------------------------------------------

  /// Derives (and caches) the AES-GCM key for a conversation.
  /// Returns null when encryption isn't possible yet (peer has no key).
  Future<SecretKey?> conversationKey(String conversationId) async {
    final cached = _convKeys[conversationId];
    if (cached != null) return cached;
    final myPriv = _privateKey;
    final peerPub = await _peerPublicKeyForConversation(conversationId);
    if (myPriv == null || peerPub == null) return null;

    final myPair = await _x25519.newKeyPairFromSeed(myPriv);
    final shared = await _x25519.sharedSecretKey(
      keyPair: myPair,
      remotePublicKey: SimplePublicKey(peerPub, type: KeyPairType.x25519),
    );
    final key = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: const <int>[],
      info: utf8.encode('$_hkdfInfoPrefix|$conversationId'),
    );
    _convKeys[conversationId] = key;
    return key;
  }

  // ---------------------------------------------------------------------
  // Message encryption / decryption
  // ---------------------------------------------------------------------

  /// Encrypts a user text message for storage.
  /// Falls back to plaintext when the peer has no key yet.
  Future<String> encryptForConversation(String conversationId, String plain) async {
    final key = await conversationKey(conversationId);
    if (key == null) return plain;

    final nonce = Uint8List(12);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _random.nextInt(256);
    }
    final box = await _aesGcm.encrypt(
      utf8.encode(plain),
      secretKey: key,
      nonce: nonce,
    );

    final payload = BytesBuilder()
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return _payloadPrefix + base64Encode(payload.toBytes());
  }

  /// Decrypts a stored payload. Plaintext / legacy payloads pass through.
  Future<String> decryptForConversation(String conversationId, String payload) async {
    if (!payload.startsWith(_payloadPrefix)) return payload;

    final key = await conversationKey(conversationId);
    if (key == null) return '🔒 Unable to decrypt';

    try {
      final raw = base64Decode(payload.substring(_payloadPrefix.length));
      if (raw.length < 12 + 16) return '🔒 Unable to decrypt';
      final nonce = raw.sublist(0, 12);
      final mac = Mac(raw.sublist(raw.length - 16));
      final cipher = raw.sublist(12, raw.length - 16);
      final clear = await _aesGcm.decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return utf8.decode(clear);
    } catch (_) {
      return '🔒 Unable to decrypt';
    }
  }

  /// Forgets in-memory keys (e.g. on logout / user switch).
  void reset() {
    _privateKey = null;
    _convKeys.clear();
  }
}
