import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/screens/incomes_list_screen.dart';
import 'package:new_my_car_app/providers/car_provider.dart';

void main() {
  Widget buildTestableScreen() {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => CarProvider(),
              child: const IncomesListScreen(),
            ),
          ),
        ],
      ),
    );
  }

  group('IncomesListScreen Widget Tests', () {
    testWidgets('should display the app bar title and add income button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pump();

      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets(
      'should display an error state with a retry button when cars fail to load',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableScreen());

        // Sin un usuario autenticado, el intento automático de
        // carProvider.loadCars() falla, y la pantalla debe mostrar un estado
        // de error (no el estado "vacío") junto con un botón para reintentar.
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('No hay vehículos'), findsNothing);
      },
    );
  });
}
