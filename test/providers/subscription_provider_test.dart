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

    test('on iOS opens the App Store app (itms-apps), not Safari', () async {
      final launched = <Uri>[];
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (uri) async {
          launched.add(uri);
          return true;
        },
        platform: TargetPlatform.iOS,
      );

      expect(await provider.openManageSubscription(), isTrue);
      // Con éxito en la app App Store no abre la web.
      expect(launched, [
        Uri.parse('itms-apps://apps.apple.com/account/subscriptions'),
      ]);
    });

    test(
      'on iOS the RevenueCat apps.apple.com URL also opens the App Store app',
      () async {
        final launched = <Uri>[];
        final provider = SubscriptionProvider(
          fetchManagementUrl: () async =>
              'https://apps.apple.com/account/subscriptions',
          launchUri: (uri) async {
            launched.add(uri);
            return true;
          },
          platform: TargetPlatform.iOS,
        );

        await provider.openManageSubscription();

        expect(launched.single.scheme, 'itms-apps');
      },
    );

    test(
      'on iOS falls back to the web page when the App Store app cannot open',
      () async {
        final launched = <Uri>[];
        final provider = SubscriptionProvider(
          fetchManagementUrl: () async => null,
          launchUri: (uri) async {
            launched.add(uri);
            return uri.scheme ==
                'https'; // p. ej. el simulador no tiene App Store
          },
          platform: TargetPlatform.iOS,
        );

        expect(await provider.openManageSubscription(), isTrue);
        expect(launched, [
          Uri.parse('itms-apps://apps.apple.com/account/subscriptions'),
          Uri.parse(appStoreSubscriptionsUrl),
        ]);
      },
    );

    test('on iOS falls back to the web page when itms-apps throws', () async {
      final launched = <Uri>[];
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (uri) async {
          launched.add(uri);
          if (uri.scheme == 'itms-apps') throw Exception('sin App Store');
          return true;
        },
        platform: TargetPlatform.iOS,
      );

      expect(await provider.openManageSubscription(), isTrue);
      expect(launched.last, Uri.parse(appStoreSubscriptionsUrl));
    });

    test('on Android opens the Play Store page once', () async {
      final launched = <Uri>[];
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (uri) async {
          launched.add(uri);
          return true;
        },
        platform: TargetPlatform.android,
      );

      await provider.openManageSubscription();

      expect(launched, [Uri.parse(playStoreSubscriptionsUrl)]);
    });

    test('returns false when the store page cannot be opened', () async {
      final provider = SubscriptionProvider(
        fetchManagementUrl: () async => null,
        launchUri: (_) async => false,
        platform: TargetPlatform.android,
      );

      expect(await provider.openManageSubscription(), isFalse);
    });

    test(
      'returns false on iOS when neither the app nor the web opens',
      () async {
        final provider = SubscriptionProvider(
          fetchManagementUrl: () async => null,
          launchUri: (_) async => false,
          platform: TargetPlatform.iOS,
        );

        expect(await provider.openManageSubscription(), isFalse);
      },
    );

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
