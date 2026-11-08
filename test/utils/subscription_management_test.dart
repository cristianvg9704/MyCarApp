import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/subscription_management.dart';

void main() {
  group('subscriptionManagementUrl', () {
    test('prefers the URL provided by RevenueCat', () {
      expect(
        subscriptionManagementUrl(
          managementUrl: 'https://apps.apple.com/account/subscriptions?x=1',
          platform: TargetPlatform.iOS,
        ),
        'https://apps.apple.com/account/subscriptions?x=1',
      );
    });

    test('falls back to the App Store page on iOS', () {
      expect(
        subscriptionManagementUrl(platform: TargetPlatform.iOS),
        appStoreSubscriptionsUrl,
      );
    });

    test('falls back to the Play Store page on Android', () {
      expect(
        subscriptionManagementUrl(platform: TargetPlatform.android),
        playStoreSubscriptionsUrl,
      );
    });

    test('treats a blank RevenueCat URL as missing', () {
      expect(
        subscriptionManagementUrl(
          managementUrl: '   ',
          platform: TargetPlatform.iOS,
        ),
        appStoreSubscriptionsUrl,
      );
    });

    test('returns null where there is no store (desktop)', () {
      expect(
        subscriptionManagementUrl(
          managementUrl: 'https://example.com',
          platform: TargetPlatform.macOS,
        ),
        isNull,
      );
    });
  });
}
