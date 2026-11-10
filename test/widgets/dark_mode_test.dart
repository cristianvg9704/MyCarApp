import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/alert_provider.dart';
import 'package:new_my_car_app/providers/app_provider.dart';
import 'package:new_my_car_app/providers/auth_provider.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/mileage_provider.dart';
import 'package:new_my_car_app/providers/subscription_provider.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/providers/trip_provider.dart';
import 'package:new_my_car_app/providers/user_provider.dart';
import 'package:new_my_car_app/screens/add_alert_screen.dart';
import 'package:new_my_car_app/screens/add_transaction_screen.dart';
import 'package:new_my_car_app/screens/add_vehicle_screen.dart';
import 'package:new_my_car_app/screens/alerts_list_screen.dart';
import 'package:new_my_car_app/screens/auth/forgot_password_screen.dart';
import 'package:new_my_car_app/screens/auth/register_screen.dart';
import 'package:new_my_car_app/screens/car_finances_screen.dart';
import 'package:new_my_car_app/screens/finances_list_screen.dart';
import 'package:new_my_car_app/screens/onboarding/onboarding_screen.dart';
import 'package:new_my_car_app/screens/auth/login_screen.dart';
import 'package:new_my_car_app/screens/car_detail_screen.dart';
import 'package:new_my_car_app/screens/home_screen.dart';
import 'package:new_my_car_app/screens/profile_screen.dart';
import 'package:new_my_car_app/screens/settings_screen.dart';
import 'package:new_my_car_app/screens/subscription_screen.dart';
import 'package:new_my_car_app/screens/vehicles_list_screen.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';
import 'package:new_my_car_app/services/subscription_service.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';
import 'package:new_my_car_app/utils/app_theme.dart';
import 'package:new_my_car_app/utils/my_car_palette.dart';
import 'package:new_my_car_app/widgets/empty_state.dart';
import 'package:new_my_car_app/widgets/home_trip_card.dart';
import 'package:new_my_car_app/widgets/stat_card.dart';
import 'package:new_my_car_app/widgets/transaction_tile.dart';
import 'package:new_my_car_app/widgets/voice_entry_sheet.dart';

import '../helpers/contrast.dart';
import '../helpers/fake_speech_recognizer.dart';
import '../helpers/supabase_test_init.dart';

class _Cars extends CarProvider {
  final List<Car> list;
  _Cars(this.list);

  @override
  List<Car> get cars => list;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async {}
}

class _Subscription extends SubscriptionProvider {
  final SubscriptionTier tier;
  final List<Package> packages;
  _Subscription(this.tier, this.packages);

  @override
  SubscriptionTier get currentTier => tier;

  @override
  bool get isPremium => tier != SubscriptionTier.free;

  @override
  List<Package> get availablePackages => packages;

  @override
  bool get isLoading => false;

  @override
  Future<void> initialize() async {}
}

class _Repo implements TransactionRepository {
  @override
  Future<String> add(CarTransaction t) async => 'id';

  @override
  Future<List<CarTransaction>> getByCar(String carId) async => [];

  @override
  Future<void> update(CarTransaction t) async {}

  @override
  Future<void> delete(String id) async {}
}

Package _package(String id, String productId, String price) => Package(
  id,
  id.contains('annual') ? PackageType.annual : PackageType.monthly,
  StoreProduct(productId, 'desc', 'title', 5, price, 'USD'),
  const PresentedOfferingContext('default', null, null),
);

final _car = Car(
  id: 'c1',
  userId: 'u1',
  brand: 'Toyota',
  model: 'Corolla',
  year: 2020,
  plateNumber: 'ABC123',
  color: 'Rojo',
  notes: 'Cambio de aceite pendiente',
);

final _transactions = [
  CarTransaction(
    id: 'i1',
    userId: 'u1',
    carId: 'c1',
    description: 'Viaje aeropuerto',
    amount: 120000,
    date: DateTime.now(),
  ),
  CarTransaction(
    id: 'e1',
    userId: 'u1',
    carId: 'c1',
    type: TransactionType.expense,
    description: 'Tanqueo Terpel',
    amount: 40000,
    date: DateTime.now(),
    category: TransactionCategory.fuel,
  ),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'has_seen_subscription': true});
    await initSupabaseForTests();
  });

  Future<void> pumpDark(
    WidgetTester tester,
    Widget home, {
    List<SingleChildWidget> providers = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final app = MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => home)],
      ),
    );
    await tester.pumpWidget(
      providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
    );
    await tester.pumpAndSettle();
  }

  void expectReadable(WidgetTester tester) {
    final problems = lowContrastTexts(tester);
    expect(
      problems,
      isEmpty,
      reason: 'Textos casi ilegibles en modo oscuro:\n${problems.join('\n')}',
    );
  }

  testWidgets('el tema oscuro se aplica (no el claro)', (tester) async {
    await pumpDark(tester, const Scaffold(body: Text('hola')));

    final context = tester.element(find.text('hola'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(context.palette.background, MyCarPalette.dark.background);
  });

  group('widgets básicos', () {
    testWidgets('EmptyState', (tester) async {
      await pumpDark(
        tester,
        const Scaffold(
          body: EmptyState(
            icon: Icons.inbox,
            title: 'Sin datos',
            message: 'Aún no hay nada por aquí',
          ),
        ),
      );
      expectReadable(tester);
    });

    testWidgets('StatCard y TransactionTile', (tester) async {
      await pumpDark(
        tester,
        Scaffold(
          body: Column(
            children: [
              const StatCard(
                label: 'Ingresos',
                value: r'$120.000',
                icon: Icons.trending_up,
              ),
              TransactionTile(transaction: _transactions.first),
              TransactionTile(transaction: _transactions.last),
            ],
          ),
        ),
      );
      expectReadable(tester);
    });
  });

  group('pantallas', () {
    testWidgets('inicio con vehículos', (tester) async {
      await pumpDark(
        tester,
        const HomeScreen(),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider(create: (_) => MileageProvider()),
        ],
      );

      expect(find.text('Toyota Corolla'), findsOneWidget);
      expectReadable(tester);
    });

    testWidgets('inicio sin vehículos', (tester) async {
      await pumpDark(
        tester,
        const HomeScreen(),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([])),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('tarjeta de viaje', (tester) async {
      await pumpDark(
        tester,
        const Scaffold(body: HomeTripCard()),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider(create: (_) => MileageProvider()),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('lista de vehículos', (tester) async {
      await pumpDark(
        tester,
        const VehiclesListScreen(),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('detalle del vehículo: todas las pestañas', (tester) async {
      await pumpDark(
        tester,
        CarDetailScreen(
          carId: 'c1',
          carLoader: (_) async => _car,
          transactionsLoader: (_) async => _transactions,
        ),
        providers: [
          ChangeNotifierProvider(create: (_) => MileageProvider()),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
        ],
      );

      for (final tab in ['Detalle', 'Movimientos', 'Gráficos', 'Kilometraje']) {
        await tester.tap(find.widgetWithText(Tab, tab));
        await tester.pumpAndSettle();
        final problems = lowContrastTexts(tester);
        expect(
          problems,
          isEmpty,
          reason: 'Pestaña $tab:\n${problems.join('\n')}',
        );
      }
    });

    testWidgets('suscripción', (tester) async {
      await pumpDark(
        tester,
        const SubscriptionScreen(),
        providers: [
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: _Subscription(SubscriptionTier.monthly, [
              _package(r'$rc_monthly', 'rc_monthly', r'$5.00'),
              _package(r'$rc_annual', 'rc_annual', r'$50.00'),
            ]),
          ),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('ajustes', (tester) async {
      await pumpDark(
        tester,
        const SettingsScreen(),
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: _Subscription(SubscriptionTier.free, const []),
          ),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('perfil', (tester) async {
      await pumpDark(
        tester,
        const ProfileScreen(),
        providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      );
      expectReadable(tester);
    });

    testWidgets('inicio de sesión', (tester) async {
      await pumpDark(
        tester,
        const LoginScreen(),
        providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      );
      expectReadable(tester);
    });

    testWidgets('registro', (tester) async {
      await pumpDark(
        tester,
        const RegisterScreen(),
        providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      );
      expectReadable(tester);
    });

    testWidgets('recuperar contraseña', (tester) async {
      await pumpDark(
        tester,
        const ForgotPasswordScreen(),
        providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      );
      expectReadable(tester);
    });

    testWidgets('bienvenida', (tester) async {
      await pumpDark(tester, const OnboardingScreen());
      expectReadable(tester);
    });

    testWidgets('agregar vehículo', (tester) async {
      await pumpDark(
        tester,
        const AddVehicleScreen(),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('agregar alerta', (tester) async {
      await pumpDark(
        tester,
        const AddAlertScreen(initialCarId: 'c1'),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(create: (_) => AlertProvider()),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('lista de alertas', (tester) async {
      await pumpDark(
        tester,
        const AlertsListScreen(),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(create: (_) => AlertProvider()),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('finanzas', (tester) async {
      await pumpDark(
        tester,
        FinancesListScreen(repository: _Repo()),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: _Repo()),
          ),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('finanzas de un vehículo', (tester) async {
      await pumpDark(
        tester,
        const CarFinancesScreen(carId: 'c1'),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: _Repo()),
          ),
        ],
      );
      expectReadable(tester);
    });

    testWidgets('registrar movimiento (formulario)', (tester) async {
      await pumpDark(
        tester,
        AddTransactionScreen(
          initialCarId: 'c1',
          initialType: TransactionType.expense,
          currentUserId: () => 'u1',
          speechRecognizer: FakeSpeechRecognizer(),
        ),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: _Repo()),
          ),
        ],
      );
      expectReadable(tester);
    });
  });

  group('hoja de voz', () {
    late FakeSpeechRecognizer recognizer;

    Future<void> openSheet(WidgetTester tester) async {
      recognizer = FakeSpeechRecognizer();
      await pumpDark(
        tester,
        Scaffold(
          body: VoiceEntrySheet(
            carId: 'c1',
            speechRecognizer: recognizer,
            currentUserId: () => 'u1',
            haptic: () async {},
          ),
        ),
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: _Cars([_car])),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: _Repo()),
          ),
        ],
      );
    }

    testWidgets('listo', (tester) async {
      await openSheet(tester);
      expectReadable(tester);
    });

    testWidgets('escuchando', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('voice_mic_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      recognizer.say('gasolina sesenta mil');
      await tester.pump(const Duration(milliseconds: 300));

      expectReadable(tester);
      // Salir de "escuchando" para detener los timers.
      await tester.tap(find.byKey(const Key('voice_cancel_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('revisar y guardar', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('voice_mic_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      recognizer.say('gasolina sesenta mil', isFinal: true);
      await tester.pumpAndSettle();

      expect(find.text('Revisa y guarda'), findsOneWidget);
      expectReadable(tester);
    });

    testWidgets('error de permisos', (tester) async {
      await openSheet(tester);
      recognizer.initFailure = SpeechFailure.permissionDenied;
      await tester.tap(find.byKey(const Key('voice_mic_button')));
      await tester.pumpAndSettle();

      expect(find.text('Necesito tu permiso'), findsOneWidget);
      expectReadable(tester);
    });
  });
}
