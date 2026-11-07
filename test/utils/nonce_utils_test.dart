import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/nonce_utils.dart';

void main() {
  group('generateRawNonce', () {
    test('has the requested length (32 by default)', () {
      expect(generateRawNonce(), hasLength(32));
      expect(generateRawNonce(64), hasLength(64));
    });

    test('only uses URL-safe characters', () {
      expect(generateRawNonce(200), matches(RegExp(r'^[0-9A-Za-z\-._]+$')));
    });

    test('is different on every call', () {
      final nonces = {for (var i = 0; i < 50; i++) generateRawNonce()};

      expect(nonces, hasLength(50));
    });
  });

  group('sha256OfString', () {
    test('matches known SHA-256 vectors', () {
      expect(
        sha256OfString(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256OfString('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('is deterministic and 64 hex characters long', () {
      final hash = sha256OfString('nonce');

      expect(sha256OfString('nonce'), hash);
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });
}
