import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the E2EE scheme used by E2eeService:
/// X25519 ECDH + HKDF(conversation id) -> AES-256-GCM.
void main() {
  final x25519 = X25519();
  final aes = AesGcm.with256bits();
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final infoPrefix = '1%better-e2ee-v1';
  const conversationId = 'conv-12345';
  final info = utf8.encode('$infoPrefix|$conversationId');

  Future<SecretKey> conversationKey(SimpleKeyPair mine, List<int> peerPub) async {
    final shared = await x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(peerPub, type: KeyPairType.x25519),
    );
    return hkdf.deriveKey(secretKey: shared, nonce: const [], info: info);
  }

  test('both peers derive the same conversation key via ECDH', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();

    final alicePub = await alice.extractPublicKey();
    final bobPub = await bob.extractPublicKey();

    final aliceKey = await conversationKey(alice, bobPub.bytes);
    final bobKey = await conversationKey(bob, alicePub.bytes);

    expect(await aliceKey.extractBytes(), await bobKey.extractBytes());
  });

  test('AES-GCM roundtrip of an encrypted text payload', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final alicePub = await alice.extractPublicKey();
    final bobPub = await bob.extractPublicKey();

    final key = await conversationKey(alice, bobPub.bytes);

    final plain = 'hello from alice 🌱';
    final nonce = Uint8List(12);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = i + 1;
    }

    final box = await aes.encrypt(utf8.encode(plain), secretKey: key, nonce: nonce);
    final payload = BytesBuilder()
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    final b64 = 'e1:${base64Encode(payload.toBytes())}';

    // Bob decrypts using his private key + Alice's public key.
    final bobKey = await conversationKey(bob, alicePub.bytes);
    final raw = base64Decode(b64.substring(3));
    final mac = Mac(raw.sublist(raw.length - 16));
    final cipher = raw.sublist(12, raw.length - 16);
    final clear = await aes.decrypt(
      SecretBox(cipher, nonce: raw.sublist(0, 12), mac: mac),
      secretKey: bobKey,
    );

    expect(utf8.decode(clear), plain);
  });

  test('tampered payload fails to decrypt', () async {
    final alice = await x25519.newKeyPair();
    final bob = await x25519.newKeyPair();
    final alicePub = await alice.extractPublicKey();
    final bobPub = await bob.extractPublicKey();

    final key = await conversationKey(alice, bobPub.bytes);
    final bobKey = await conversationKey(bob, alicePub.bytes);

    final nonce = Uint8List(12);
    final box = await aes.encrypt(utf8.encode('secret'), secretKey: key, nonce: nonce);
    final payload = BytesBuilder()
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    final raw = payload.toBytes();
    raw[raw.length - 1] ^= 0x01; // flip a MAC bit

    final mac = Mac(raw.sublist(raw.length - 16));
    final cipher = raw.sublist(12, raw.length - 16);
    expect(
      () => aes.decrypt(
        SecretBox(cipher, nonce: raw.sublist(0, 12), mac: mac),
        secretKey: bobKey,
      ),
      throwsA(isA<Object>()),
    );
  });
}
