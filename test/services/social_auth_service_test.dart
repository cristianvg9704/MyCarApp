import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/services/social_auth_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('DeviceSocialAuthService.isAvailable', () {
    final service = DeviceSocialAuthService();

    test('Apple is available on iOS and macOS only', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(service.isAvailable(SocialProvider.apple), isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(service.isAvailable(SocialProvider.apple), isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(service.isAvailable(SocialProvider.apple), isFalse);
    });

    test('Google is available on every platform', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(service.isAvailable(SocialProvider.google), isTrue);
      }
    });
  });

  group('DeviceSocialAuthService.signIn', () {
    test('Apple fails with a clear message where it is unavailable', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        DeviceSocialAuthService().signIn(SocialProvider.apple),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.message,
            'message',
            contains('no está disponible'),
          ),
        ),
      );
    });

    test('Google fails with a clear message while it is not configured', () {
      // En tests no se pasa GOOGLE_WEB_CLIENT_ID
      expect(
        DeviceSocialAuthService().signIn(SocialProvider.google),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.message,
            'message',
            contains('no está configurado'),
          ),
        ),
      );
    });
  });
}
