import 'dart:convert';

import 'package:cryptography/cryptography.dart' as cg;
import 'package:goss/services/chat_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatCrypto device key', () {
    test('keyIdOf is stable', () {
      final pub =
          '3z1d2asN9y4VrY8kKpQ5tW7mJx9bA2xC4eE6fH8gI0jK1lM2nO3pQ4rS5tU6vW7xY8zA9bB';
      expect(ChatCrypto.keyIdOf(pub), ChatCrypto.keyIdOf(pub));
      expect(ChatCrypto.keyIdOf(pub).length, 24);
    });

    test('device public key is a 32-byte X25519 key', () async {
      final pub = await ChatCrypto.myPublicKeyB64();
      expect(base64Decode(pub).length, 32);
    });
  });

  group('ChatCrypto sealed box (delivery of the conversation key)', () {
    test('team device can open a conversation sealed to it', () async {
      final convKey = ChatCrypto.newConversationKey();
      final myPub = await ChatCrypto.myPublicKeyB64();

      // A second (simulated team) device.
      final otherPair = await cg.X25519().newKeyPair();
      final otherPub = base64Encode((await otherPair.extractPublicKey()).bytes);

      final convId = 'test-conversation-1';
      final sealed = await ChatCrypto.sealConversationKey(
        conversationId: convId,
        convKeyB64: convKey,
        recipientsPublicB64: [myPub, otherPub],
      );

      expect(sealed.sealed.length, 2);
      expect(sealed.sealed.keys, containsAll([ChatCrypto.keyIdOf(myPub), ChatCrypto.keyIdOf(otherPub)]));

      // The app device opens its own box.
      final opened = await ChatCrypto.openConversationKey(
        conversationId: convId,
        ephPubB64: sealed.ephPubB64,
        sealedB64: sealed.sealed[ChatCrypto.keyIdOf(myPub)]!,
        nonceB64: sealed.nonces[ChatCrypto.keyIdOf(myPub)]!,
        macB64: sealed.macs[ChatCrypto.keyIdOf(myPub)]!,
      );
      expect(opened, convKey);
    });

    test('tampered box is rejected', () async {
      final myPub = await ChatCrypto.myPublicKeyB64();
      final sealed = await ChatCrypto.sealConversationKey(
        conversationId: 'test-tamper',
        convKeyB64: ChatCrypto.newConversationKey(),
        recipientsPublicB64: [myPub],
      );
      final keyId = ChatCrypto.keyIdOf(myPub);
      final mac = base64Decode(sealed.macs[keyId]!);
      mac[0] ^= 0x01; // flip one bit
      final opened = await ChatCrypto.openConversationKey(
        conversationId: 'test-tamper',
        ephPubB64: sealed.ephPubB64,
        sealedB64: sealed.sealed[keyId]!,
        nonceB64: sealed.nonces[keyId]!,
        macB64: base64Encode(mac),
      );
      expect(opened, isNull);
    });
  });

  group('ChatCrypto AES-GCM messages', () {
    final convKey = ChatCrypto.newConversationKey();

    test('text roundtrip', () async {
      const plain =
          'السلام عليكم، أريد تفعيل اشتراك الشحن لأن العملاء طلبوه أكثر من مرة';
      final encrypted = await ChatCrypto.encryptText(convKey, plain);
      final decrypted = await ChatCrypto.decryptText(
        convKey,
        encrypted.$1,
        encrypted.$2,
        encrypted.$3,
      );
      expect(decrypted, plain);
      expect(
        encrypted.$2,
        isNot(contains(plain)),
        reason: 'Firestore must never see plaintext',
      );
    });

    test('wrong key decrypts to null', () async {
      final encrypted = await ChatCrypto.encryptText(convKey, 'another message');
      final other = ChatCrypto.newConversationKey();
      final decrypted = await ChatCrypto.decryptText(other, encrypted.$1, encrypted.$2, encrypted.$3);
      expect(decrypted, isNull);
    });

    test('image bytes roundtrip', () async {
      final bytes = List<int>.generate(4096, (i) => i % 251);
      final encrypted = await ChatCrypto.encryptBytes(convKey, bytes);
      final decrypted = await ChatCrypto.decryptBytes(convKey, encrypted.$1, encrypted.$2, encrypted.$3);
      expect(decrypted, equals(bytes));
    });
  });
}