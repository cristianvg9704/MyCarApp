import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/main.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/providers/alert_provider.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/trip_provider.dart';
import 'package:new_my_car_app/providers/user_provider.dart';

/// Evita Supabase: la lista de vehículos se controla desde el test.
class _FakeCarProvider extends CarProvider {
  final List<Car> _fakeCars;

  _FakeCarProvider([this._fakeCars = const []]);

  @override
  List<Car> get cars => _fakeCars;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async {}
}

/// La app completa (`MyCarApp`) depende de Supabase inicializado, así que se
/// prueba la navegación principal con los providers necesarios.
void main() {
  Future<void> pumpNavigation(WidgetTester tester, {int initialIndex = 0}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CarProvider>(create: (_) => _FakeCarProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider(create: (_) => AlertProvider()),
        ],
        child: MaterialApp(
          home: MainNavigationScreen(initialIndex: initialIndex),
        ),
      ),
    );
    // MainNavigationScreen recarga los vehículos tras 500 ms si no hay ninguno
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('MainNavigationScreen', () {
    testWidgets('shows the bottom navigation items', (tester) async {
      await pumpNavigation(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Finanzas'), findsOneWidget);
      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('starts on Home', (tester) async {
      await pumpNavigation(tester);

      expect(find.text('Hola,'), findsOneWidget);
    });

    testWidgets('can start on the Finanzas tab', (tester) async {
      await pumpNavigation(tester, initialIndex: 1);

      expect(find.text('Hola,'), findsNothing);
      // Título de la pantalla + etiqueta de la barra de navegación
      expect(find.text('Finanzas'), findsNWidgets(2));
    });

    testWidgets('tapping Finanzas leaves Home', (tester) async {
      await pumpNavigation(tester);

      await tester.tap(find.text('Finanzas'));
      await tester.pumpAndSettle();

      expect(find.text('Hola,'), findsNothing);
      expect(find.text('Finanzas'), findsNWidgets(2));
    });
  });
}
