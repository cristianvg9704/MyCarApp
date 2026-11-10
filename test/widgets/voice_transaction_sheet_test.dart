import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';
import 'package:new_my_car_app/widgets/voice_transaction_sheet.dart';

import '../helpers/fake_speech_recognizer.dart';

class _FakeRepository implements TransactionRepository {
  final List<CarTransaction> added = [];
  Object? failWith;

  @override
  Future<String> add(CarTransaction transaction) async {
    if (failWith != null) throw failWith!;
    added.add(transaction);
    return 'id';
  }

  @override
  Future<List<CarTransaction>> getByCar(String carId) async => added;

  @override
  Future<void> update(CarTransaction transaction) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  late _FakeRepository repository;
  late FakeSpeechRecognizer recognizer;
  bool? result;
  var sheetClosed = false;

  setUp(() {
    repository = _FakeRepository();
    recognizer = FakeSpeechRecognizer();
    result = null;
    sheetClosed = false;
  });

  /// Abre la hoja como lo hace la app (modal desde abajo) y espera su resultado.
  Future<void> openSheet(
    WidgetTester tester, {
    String? Function()? currentUserId,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(repository: repository),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => VoiceTransactionSheet(
                        carId: 'c1',
                        speechRecognizer: recognizer,
                        currentUserId: currentUserId ?? () => 'u1',
                      ),
                    );
                    sheetClosed = true;
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> say(
    WidgetTester tester,
    String text, {
    bool isFinal = true,
  }) async {
    recognizer.say(text, isFinal: isFinal);
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('voice_save_button')));

  testWidgets('empieza a escuchar y NO muestra el formulario de movimientos', (
    tester,
  ) async {
    await openSheet(tester);

    expect(recognizer.initializeCalls, 1);
    expect(recognizer.isListening, isTrue);
    expect(find.text('Escuchando… toca para terminar'), findsOneWidget);
    // Sin formulario: ni campos, ni selector de tipo, ni título del modal.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(SegmentedButton<TransactionType>), findsNothing);
    expect(find.text('Registrar Movimiento'), findsNothing);
    expect(find.text('Guardar Ingreso'), findsNothing);
    expect(find.text('Guardar Egreso'), findsNothing);
  });

  testWidgets('muestra el texto que se va entendiendo', (tester) async {
    await openSheet(tester);

    await say(tester, 'gasté cincuenta', isFinal: false);

    expect(find.text('“gasté cincuenta”'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('al terminar muestra solo lo que se agregó por voz', (
    tester,
  ) async {
    await openSheet(tester);

    await say(tester, 'gasté cincuenta mil en gasolina ayer');

    expect(find.text('“gasté cincuenta mil en gasolina ayer”'), findsOneWidget);
    expect(find.byKey(const Key('voice_draft_summary')), findsOneWidget);
    expect(find.text('Egreso'), findsOneWidget);
    expect(find.text(r'$50.000'), findsOneWidget);
    expect(find.text('Combustible'), findsWidgets);
    expect(find.text('Esto fue lo que entendí'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    // El micrófono ya no está activo.
    expect(recognizer.isListening, isFalse);
    expect(find.text('Escuchando… toca para terminar'), findsNothing);
  });

  testWidgets('tocar el micrófono mientras escucha termina la captura', (
    tester,
  ) async {
    await openSheet(tester);
    recognizer.say('me pagaron cien mil por una carrera');
    await tester.pump();

    await tester.tap(find.byKey(const Key('voice_mic_button')));
    await tester.pumpAndSettle();

    expect(recognizer.stopCalls, 1);
    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text(r'$100.000'), findsOneWidget);
    expect(find.text('Escuchando… toca para terminar'), findsNothing);
  });

  testWidgets('guardar crea el movimiento, apaga el micrófono y cierra', (
    tester,
  ) async {
    await openSheet(tester);
    await say(tester, 'gasté cincuenta mil en gasolina');

    await tester.tap(find.byKey(const Key('voice_save_button')));
    await tester.pumpAndSettle();

    expect(repository.added, hasLength(1));
    final saved = repository.added.single;
    expect(saved.userId, 'u1');
    expect(saved.carId, 'c1');
    expect(saved.type, TransactionType.expense);
    expect(saved.category, TransactionCategory.fuel);
    expect(saved.amount, 50000);
    // La hoja se cerró con éxito y el reconocedor quedó apagado.
    expect(sheetClosed, isTrue);
    expect(result, isTrue);
    expect(find.byType(VoiceTransactionSheet), findsNothing);
    expect(recognizer.isListening, isFalse);
    expect(recognizer.cancelCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('sin monto no se puede guardar y se pide repetir', (
    tester,
  ) async {
    await openSheet(tester);

    await say(tester, 'gasté en gasolina');

    expect(find.text('No entendí el monto. Intenta de nuevo.'), findsOneWidget);
    expect(find.text('Sin monto'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(repository.added, isEmpty);
  });

  testWidgets('"Hablar de nuevo" descarta lo anterior y vuelve a escuchar', (
    tester,
  ) async {
    await openSheet(tester);
    await say(tester, 'gasté diez mil en peaje');

    await tester.tap(find.byKey(const Key('voice_retry_button')));
    await tester.pumpAndSettle();

    expect(recognizer.initializeCalls, 2);
    expect(recognizer.isListening, isTrue);
    expect(find.byKey(const Key('voice_draft_summary')), findsNothing);
    expect(find.text('“gasté diez mil en peaje”'), findsNothing);
  });

  testWidgets('sin voz muestra "no te escuché"', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('voice_mic_button')));
    await tester.pumpAndSettle();

    expect(find.text('No te escuché. Intenta de nuevo.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('permiso negado muestra el mensaje y no escucha', (tester) async {
    recognizer.initFailure = SpeechFailure.permissionDenied;

    await openSheet(tester);

    expect(
      find.text(
        'Activa el micrófono y el reconocimiento de voz para MyCar en Ajustes.',
      ),
      findsOneWidget,
    );
    expect(recognizer.isListening, isFalse);
  });

  testWidgets('cerrar con la X apaga el micrófono y no guarda', (tester) async {
    await openSheet(tester);
    recognizer.say('gasté diez mil');
    await tester.pump();

    await tester.tap(find.byKey(const Key('voice_close_button')));
    await tester.pumpAndSettle();

    expect(sheetClosed, isTrue);
    expect(result, isNull);
    expect(recognizer.isListening, isFalse);
    expect(recognizer.cancelCalls, greaterThanOrEqualTo(1));
    expect(repository.added, isEmpty);
  });

  testWidgets('si falla el guardado la hoja sigue abierta con el error', (
    tester,
  ) async {
    repository.failWith = Exception('sin red');
    await openSheet(tester);
    await say(tester, 'gasté diez mil en peaje');

    await tester.tap(find.byKey(const Key('voice_save_button')));
    await tester.pumpAndSettle();

    expect(find.byType(VoiceTransactionSheet), findsOneWidget);
    expect(find.textContaining('Error al guardar'), findsOneWidget);
    expect(recognizer.isListening, isFalse);
    // Se puede reintentar.
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('sin usuario autenticado no guarda', (tester) async {
    await openSheet(tester, currentUserId: () => null);
    await say(tester, 'gasté diez mil en peaje');

    await tester.tap(find.byKey(const Key('voice_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Error: Usuario no autenticado'), findsOneWidget);
    expect(repository.added, isEmpty);
  });
}
