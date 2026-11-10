import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_my_car_app/providers/subscription_provider.dart';
import 'package:new_my_car_app/screens/subscription_screen.dart';
import 'package:new_my_car_app/services/subscription_service.dart';

class _FakeSubscriptionProvider extends SubscriptionProvider {
  SubscriptionTier tier;
  List<Package> packages;
  int manageCalls = 0;
  bool manageResult = true;
  bool purchaseResult = true;
  final List<Package> purchased = [];

  _FakeSubscriptionProvider({required this.tier, required this.packages});

  @override
  SubscriptionTier get currentTier => tier;

  @override
  bool get isPremium => tier != SubscriptionTier.free;

  @override
  List<Package> get availablePackages => packages;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> purchasePackage(Package package) async {
    purchased.add(package);
    return purchaseResult;
  }

  @override
  Future<bool> openManageSubscription() async {
    manageCalls++;
    return manageResult;
  }

  @override
  Future<bool> restorePurchases() async => false;

  /// Simula que el servicio terminó de cargar el plan o los paquetes.
  void refresh() => notifyListeners();
}

Package _package(String id, String productId, String price) => Package(
  id,
  id.contains('annual') ? PackageType.annual : PackageType.monthly,
  StoreProduct(productId, 'desc', 'title', 5, price, 'USD'),
  const PresentedOfferingContext('default', null, null),
);

void main() {
  final monthly = _package(r'$rc_monthly', 'rc_monthly', r'$5.00');
  final yearly = _package(r'$rc_annual', 'rc_annual', r'$50.00');

  late _FakeSubscriptionProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({'has_seen_subscription': true});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required SubscriptionTier tier,
    List<Package>? packages,
  }) async {
    provider = _FakeSubscriptionProvider(
      tier: tier,
      packages: packages ?? [monthly, yearly],
    );
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: provider,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/subscription',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const Scaffold(body: Text('inicio')),
              ),
              GoRoute(
                path: '/subscription',
                builder: (_, __) => const SubscriptionScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first;

  bool isSelected(WidgetTester tester, String title) => find
      .descendant(of: card(title), matching: find.byIcon(Icons.check_circle))
      .evaluate()
      .isNotEmpty;

  bool hasCurrentBadge(String title) => find
      .descendant(
        of: card(title),
        matching: find.byKey(const Key('subscription_current_badge')),
      )
      .evaluate()
      .isNotEmpty;

  Future<void> tapPrimary(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('subscription_primary_button')));
    await tester.pumpAndSettle();
  }

  group('usuario gratuito', () {
    testWidgets('el plan gratuito está marcado y es el plan actual', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.free);

      expect(isSelected(tester, 'Plan Gratuito'), isTrue);
      expect(isSelected(tester, 'Mensual'), isFalse);
      expect(isSelected(tester, 'Anual'), isFalse);
      expect(hasCurrentBadge('Plan Gratuito'), isTrue);
      expect(find.text('PLAN ACTUAL'), findsOneWidget);
      expect(find.text('Continuar con Plan Gratuito'), findsOneWidget);
    });

    testWidgets('elegir un plan de pago permite suscribirse', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.free);

      await tester.tap(find.text('Mensual'));
      await tester.pump();

      expect(isSelected(tester, 'Mensual'), isTrue);
      expect(isSelected(tester, 'Plan Gratuito'), isFalse);
      expect(find.text('Suscribirse Ahora'), findsOneWidget);

      await tapPrimary(tester);
      expect(provider.purchased, [monthly]);
      expect(find.text('inicio'), findsOneWidget);
    });
  });

  group('usuario con plan mensual', () {
    testWidgets('el plan mensual viene marcado, no el gratuito', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      expect(isSelected(tester, 'Mensual'), isTrue);
      expect(isSelected(tester, 'Plan Gratuito'), isFalse);
      expect(isSelected(tester, 'Anual'), isFalse);
    });

    testWidgets('el plan mensual muestra "Plan actual"', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      expect(hasCurrentBadge('Mensual'), isTrue);
      expect(hasCurrentBadge('Plan Gratuito'), isFalse);
      expect(hasCurrentBadge('Anual'), isFalse);
      expect(find.text('PLAN ACTUAL'), findsOneWidget);
    });

    testWidgets('el botón administra la suscripción, no dice plan gratuito', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      expect(find.text('Administrar suscripción'), findsOneWidget);
      expect(find.text('Continuar con Plan Gratuito'), findsNothing);
      expect(find.text('Suscribirse Ahora'), findsNothing);

      await tapPrimary(tester);

      expect(provider.manageCalls, 1);
      expect(provider.purchased, isEmpty);
    });

    testWidgets('si no se puede abrir la tienda lo avisa', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);
      provider.manageResult = false;

      await tapPrimary(tester);

      expect(
        find.textContaining('No se pudo abrir la administración'),
        findsOneWidget,
      );
    });

    testWidgets('elegir el anual ofrece cambiar de plan', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      await tester.tap(find.text('Anual'));
      await tester.pump();

      expect(isSelected(tester, 'Anual'), isTrue);
      expect(isSelected(tester, 'Mensual'), isFalse);
      expect(find.text('Cambiar a plan Anual'), findsOneWidget);

      await tapPrimary(tester);

      expect(provider.purchased, [yearly]);
      expect(provider.manageCalls, 0);
    });

    testWidgets('elegir el gratuito explica cómo cancelar', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      await tester.tap(find.text('Plan Gratuito'));
      await tester.pump();

      expect(isSelected(tester, 'Plan Gratuito'), isTrue);
      expect(
        find.byKey(const Key('subscription_downgrade_hint')),
        findsOneWidget,
      );
      expect(find.text('Administrar suscripción'), findsOneWidget);
      // El plan actual sigue indicado aunque el usuario mire otro.
      expect(hasCurrentBadge('Mensual'), isTrue);
    });
  });

  group('usuario con plan anual', () {
    testWidgets('el plan anual viene marcado y es el actual', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.yearly);

      expect(isSelected(tester, 'Anual'), isTrue);
      expect(isSelected(tester, 'Plan Gratuito'), isFalse);
      expect(isSelected(tester, 'Mensual'), isFalse);
      expect(hasCurrentBadge('Anual'), isTrue);
      expect(find.text('Administrar suscripción'), findsOneWidget);
    });

    testWidgets('elegir el mensual ofrece cambiar a mensual', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.yearly);

      await tester.tap(find.text('Mensual'));
      await tester.pump();

      expect(find.text('Cambiar a plan Mensual'), findsOneWidget);
    });
  });

  group('el plan se conoce después de abrir la pantalla', () {
    testWidgets('al llegar el plan, se marca solo', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.free);
      expect(isSelected(tester, 'Plan Gratuito'), isTrue);

      // RevenueCat responde con una suscripción anual activa.
      provider.tier = SubscriptionTier.yearly;
      provider.refresh();
      await tester.pumpAndSettle();

      expect(isSelected(tester, 'Anual'), isTrue);
      expect(isSelected(tester, 'Plan Gratuito'), isFalse);
      expect(hasCurrentBadge('Anual'), isTrue);
    });

    testWidgets('lo que el usuario tocó no se pisa al refrescar', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);
      await tester.tap(find.text('Anual'));
      await tester.pump();

      provider.refresh();
      await tester.pumpAndSettle();

      expect(isSelected(tester, 'Anual'), isTrue);
      expect(isSelected(tester, 'Mensual'), isFalse);
    });
  });

  testWidgets('premium cuyo paquete no está en la oferta no marca ninguno', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      tier: SubscriptionTier.yearly,
      packages: [monthly],
    );

    expect(isSelected(tester, 'Plan Gratuito'), isFalse);
    expect(isSelected(tester, 'Mensual'), isFalse);
    expect(find.text('PLAN ACTUAL'), findsNothing);
    expect(find.text('Administrar suscripción'), findsOneWidget);
  });
}
