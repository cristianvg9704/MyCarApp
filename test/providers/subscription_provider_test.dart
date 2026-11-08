import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/providers/subscription_provider.dart';
import 'package:new_my_car_app/utils/subscription_management.dart';

void main() {
  group('SubscriptionProvider.openManageSubscription', () {
    test('opens the URL given by RevenueCat', () async {
      Uri? launched;
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => 'https://example.com/manage',
        launchUri: (uri) async {
          launched = uri;
          return true;
        },
        platform: TargetPlatform.iOS,
      );

      expect(await provider.openManageSubscription(), isTrue);
      expect(launched, Uri.parse('https://example.com/manage'));
    });

    test('uses the App Store page when RevenueCat gives no URL', () async {
      Uri? launched;
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (uri) async {
          launched = uri;
          return true;
        },
        platform: TargetPlatform.iOS,
      );

      expect(await provider.openManageSubscription(), isTrue);
      expect(launched, Uri.parse(appStoreSubscriptionsUrl));
    });

    test('returns false when the store page cannot be opened', () async {
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (_) async => false,
        platform: TargetPlatform.android,
      );

      expect(await provider.openManageSubscription(), isFalse);
    });

    test('returns false instead of throwing when launching fails', () async {
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (_) async => throw Exception('boom'),
        platform: TargetPlatform.android,
      );

      expect(await provider.openManageSubscription(), isFalse);
    });

    test('does nothing on platforms without a store', () async {
      var launched = false;
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (_) async {
          launched = true;
          return true;
        },
        platform: TargetPlatform.macOS,
      );

      expect(await provider.openManageSubscription(), isFalse);
      expect(launched, isFalse);
    });
  });
}
