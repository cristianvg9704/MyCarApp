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
  bool get isPremium => tier != SubscriptionTier.none;

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
    SharedPreferences.setMockInitialValues({});
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

  bool isSelected(String title) => find
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

  bool cardShows(String title, String text) => find
      .descendant(of: card(title), matching: find.text(text))
      .evaluate()
      .isNotEmpty;

  Future<void> tapPrimary(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('subscription_primary_button')));
    await tester.pumpAndSettle();
  }

  group('no hay plan gratuito', () {
    for (final tier in SubscriptionTier.values) {
      testWidgets('no se ofrece con tier ${tier.name}', (tester) async {
        await pumpScreen(tester, tier: tier);

        expect(find.text('Plan Gratuito'), findsNothing);
        expect(find.text('Gratis'), findsNothing);
        expect(
          find.textContaining('Continuar con Plan Gratuito'),
          findsNothing,
        );
        expect(find.textContaining('gratuito'), findsNothing);
        // Solo los dos planes de pago.
        expect(find.text('Mensual'), findsOneWidget);
        expect(find.text('Anual'), findsOneWidget);
      });
    }
  });

  group('qué incluye cada plan', () {
    testWidgets('mensual: hasta 15 vehículos y soporte', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      expect(cardShows('Mensual', 'Hasta 15 vehículos'), isTrue);
      expect(cardShows('Mensual', 'Alertas y recordatorios'), isTrue);
      expect(cardShows('Mensual', 'Soporte'), isTrue);
      expect(cardShows('Mensual', 'Soporte prioritario'), isFalse);
      expect(cardShows('Mensual', 'Vehículos ilimitados'), isFalse);
    });

    testWidgets('anual: vehículos ilimitados y soporte prioritario', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      expect(cardShows('Anual', 'Vehículos ilimitados'), isTrue);
      expect(cardShows('Anual', 'Alertas y recordatorios'), isTrue);
      expect(cardShows('Anual', 'Soporte prioritario'), isTrue);
      expect(cardShows('Anual', 'Hasta 15 vehículos'), isFalse);
    });

    testWidgets('ninguno promete alertas "avanzadas" ni descuentos fijos', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      expect(find.textContaining('avanzad'), findsNothing);
      expect(find.textContaining('Ahorra'), findsNothing);
    });

    testWidgets('el precio sale de la tienda, no está escrito a mano', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        tier: SubscriptionTier.none,
        packages: [
          _package(r'$rc_monthly', 'rc_monthly', r'COP 21.900'),
          _package(r'$rc_annual', 'rc_annual', r'COP 219.900'),
        ],
      );

      expect(cardShows('Mensual', 'COP 21.900'), isTrue);
      expect(cardShows('Anual', 'COP 219.900'), isTrue);
      expect(find.textContaining('USD'), findsNothing);
    });

    testWidgets('explica la renovación automática', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      expect(
        cardShows('Mensual', 'Se renueva cada mes hasta que la canceles'),
        isTrue,
      );
      expect(
        cardShows('Anual', 'Se renueva cada año hasta que la canceles'),
        isTrue,
      );
    });
  });

  group('sin suscripción (la pantalla es obligatoria)', () {
    testWidgets('viene marcado el plan anual', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      expect(isSelected('Anual'), isTrue);
      expect(isSelected('Mensual'), isFalse);
      expect(find.text('PLAN ACTUAL'), findsNothing);
      expect(find.text('Suscribirse Ahora'), findsOneWidget);
    });

    testWidgets('se puede elegir el mensual y suscribirse', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      await tester.tap(find.text('Mensual'));
      await tester.pump();
      expect(isSelected('Mensual'), isTrue);
      expect(isSelected('Anual'), isFalse);

      await tapPrimary(tester);

      expect(provider.purchased, [monthly]);
      expect(find.text('inicio'), findsOneWidget);
    });

    testWidgets('suscribirse al anual', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      await tapPrimary(tester);

      expect(provider.purchased, [yearly]);
    });

    testWidgets('no hay cómo cerrarla: sin botón de cerrar', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Elige tu plan'), findsOneWidget);
    });

    testWidgets('el botón atrás del sistema no sale de la pantalla', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);

      final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(popScope.canPop, isFalse);
    });

    testWidgets(
      'permite restaurar compras, cerrar sesión y eliminar la cuenta',
      (tester) async {
        await pumpScreen(tester, tier: SubscriptionTier.none);

        expect(find.text('Restaurar compras'), findsOneWidget);
        expect(find.byKey(const Key('subscription_sign_out')), findsOneWidget);
        expect(
          find.byKey(const Key('subscription_delete_account')),
          findsOneWidget,
        );
      },
    );

    testWidgets('si no se pudo comprar muestra el error', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);
      provider.purchaseResult = false;

      await tapPrimary(tester);

      expect(find.text('Error al procesar la compra'), findsOneWidget);
      expect(find.text('inicio'), findsNothing);
    });
  });

  group('suscriptor mensual', () {
    testWidgets('viene marcado el mensual con "Plan actual"', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      expect(isSelected('Mensual'), isTrue);
      expect(isSelected('Anual'), isFalse);
      expect(hasCurrentBadge('Mensual'), isTrue);
      expect(hasCurrentBadge('Anual'), isFalse);
      expect(find.text('PLAN ACTUAL'), findsOneWidget);
    });

    testWidgets('el botón administra la suscripción', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      expect(find.text('Administrar suscripción'), findsOneWidget);
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

      expect(isSelected('Anual'), isTrue);
      expect(find.text('Cambiar a plan Anual'), findsOneWidget);

      await tapPrimary(tester);

      expect(provider.purchased, [yearly]);
      expect(provider.manageCalls, 0);
    });

    testWidgets('puede cerrar la pantalla y no ve cerrar sesión ni eliminar', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Tu plan'), findsOneWidget);
      expect(find.byKey(const Key('subscription_sign_out')), findsNothing);
      final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(popScope.canPop, isTrue);
    });
  });

  group('suscriptor anual', () {
    testWidgets('viene marcado el anual y es el actual', (tester) async {
      await pumpScreen(tester, tier: SubscriptionTier.yearly);

      expect(isSelected('Anual'), isTrue);
      expect(isSelected('Mensual'), isFalse);
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
    testWidgets('al comprarse un plan, pasa a ser el marcado y el actual', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.none);
      expect(isSelected('Anual'), isTrue);
      expect(find.byIcon(Icons.close), findsNothing);

      provider.tier = SubscriptionTier.monthly;
      provider.refresh();
      await tester.pumpAndSettle();

      expect(isSelected('Mensual'), isTrue);
      expect(hasCurrentBadge('Mensual'), isTrue);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('lo que el usuario tocó no se pisa al refrescar', (
      tester,
    ) async {
      await pumpScreen(tester, tier: SubscriptionTier.monthly);
      await tester.tap(find.text('Anual'));
      await tester.pump();

      provider.refresh();
      await tester.pumpAndSettle();

      expect(isSelected('Anual'), isTrue);
      expect(isSelected('Mensual'), isFalse);
    });
  });

  testWidgets('suscriptor cuyo paquete no está en la oferta: ninguno marcado', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      tier: SubscriptionTier.yearly,
      packages: [monthly],
    );

    expect(isSelected('Mensual'), isFalse);
    expect(find.text('PLAN ACTUAL'), findsNothing);
    expect(find.text('Administrar suscripción'), findsOneWidget);
  });
}
