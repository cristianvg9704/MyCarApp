import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/widgets/delete_account_dialog.dart';

void main() {
  /// Abre el diálogo desde un botón y guarda lo que devuelve.
  Future<void> pumpHost(WidgetTester tester, List<bool> results) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    results.add(await DeleteAccountDialog.show(context)),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Finder confirmButton() =>
      find.widgetWithText(FilledButton, 'Eliminar cuenta');

  testWidgets('explains what is deleted and warns about subscriptions', (
    tester,
  ) async {
    await pumpHost(tester, []);

    expect(find.textContaining('permanente'), findsOneWidget);
    expect(find.textContaining('vehículos'), findsOneWidget);
    expect(find.textContaining('suscripción'), findsOneWidget);
  });

  testWidgets('the confirm button is disabled until the word is typed', (
    tester,
  ) async {
    await pumpHost(tester, []);

    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ELIM');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ELIMINAR');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNotNull);
  });

  testWidgets('accepts lowercase and surrounding spaces', (tester) async {
    await pumpHost(tester, []);

    await tester.enterText(find.byType(TextField), '  eliminar ');
    await tester.pump();

    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNotNull);
  });

  testWidgets('confirming returns true', (tester) async {
    final results = <bool>[];
    await pumpHost(tester, results);

    await tester.enterText(find.byType(TextField), 'ELIMINAR');
    await tester.pump();
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(DeleteAccountDialog), findsNothing);
  });

  testWidgets('cancelling returns false', (tester) async {
    final results = <bool>[];
    await pumpHost(tester, results);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('dismissing the dialog returns false', (tester) async {
    final results = <bool>[];
    await pumpHost(tester, results);

    await tester.tapAt(const Offset(5, 5)); // fuera del diálogo
    await tester.pumpAndSettle();

    expect(results, [false]);
  });
}
