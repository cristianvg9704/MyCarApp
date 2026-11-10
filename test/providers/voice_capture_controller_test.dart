import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/voice_capture_controller.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';
import 'package:new_my_car_app/services/voice_transaction_parser.dart';

import '../helpers/fake_speech_recognizer.dart';

void main() {
  late FakeSpeechRecognizer recognizer;
  late VoiceCaptureController controller;
  final now = DateTime(2026, 11, 10, 12);

  setUp(() {
    recognizer = FakeSpeechRecognizer();
    controller = VoiceCaptureController(
      recognizer: recognizer,
      now: () => now,
      initialCarId: 'c1',
      vehicles: const [
        VoiceVehicle(id: 'c1', brand: 'Mazda', model: '3'),
        VoiceVehicle(id: 'c2', brand: 'Renault', model: 'Duster'),
      ],
    );
  });

  tearDown(() => controller.dispose());

  test('empieza en reposo', () {
    expect(controller.status, VoiceCaptureStatus.idle);
    expect(controller.isActive, isFalse);
    expect(controller.canSave, isFalse);
  });

  test('start abre el micrófono y muestra el texto parcial', () async {
    await controller.start();
    expect(controller.status, VoiceCaptureStatus.listening);
    expect(recognizer.isListening, isTrue);

    recognizer.say('gasté cincuenta');

    expect(controller.transcript, 'gasté cincuenta');
    expect(controller.status, VoiceCaptureStatus.listening);
  });

  test(
    'el resultado final interpreta el movimiento y apaga la escucha',
    () async {
      await controller.start();

      recognizer.say('gasté cincuenta mil en gasolina ayer', isFinal: true);

      expect(controller.status, VoiceCaptureStatus.ready);
      expect(controller.isActive, isFalse);
      final draft = controller.draft!;
      expect(draft.type, TransactionType.expense);
      expect(draft.category, TransactionCategory.fuel);
      expect(draft.amount, 50000);
      expect(draft.date, DateTime(2026, 11, 9));
      expect(controller.canSave, isTrue);
    },
  );

  test('sin verbo ni categoría el tipo por defecto es egreso', () async {
    await controller.start();

    recognizer.say('cuarenta mil', isFinal: true);

    expect(controller.draft!.type, TransactionType.expense);
  });

  test('sin monto queda listo pero no se puede guardar', () async {
    await controller.start();

    recognizer.say('gasté en gasolina', isFinal: true);

    expect(controller.status, VoiceCaptureStatus.ready);
    expect(controller.draft!.hasAmount, isFalse);
    expect(controller.canSave, isFalse);
  });

  test('stop sale de "escuchando" de inmediato y luego interpreta', () async {
    await controller.start();
    recognizer.say('gasté diez mil en peaje');

    await controller.stop();

    expect(recognizer.stopCalls, 1);
    expect(controller.status, VoiceCaptureStatus.ready);
    expect(controller.isListening, isFalse);
    expect(controller.draft!.amount, 10000);
  });

  test('stop sin texto termina en "no te escuché"', () async {
    await controller.start();

    await controller.stop();

    expect(controller.status, VoiceCaptureStatus.noSpeech);
    expect(controller.isActive, isFalse);
    expect(controller.canSave, isFalse);
  });

  test(
    'si el motor termina solo (silencio) con texto parcial, lo usa',
    () async {
      await controller.start();
      recognizer.say('gasté veinte mil en lavado');

      recognizer.finishWithoutFinalResult();

      expect(controller.status, VoiceCaptureStatus.ready);
      expect(controller.draft!.amount, 20000);
    },
  );

  test('un resultado final tardío corrige lo interpretado', () async {
    await controller.start();
    recognizer.say('gasté veinte mil');
    recognizer.finishWithoutFinalResult();

    recognizer.say('gasté veinte mil en lavado', isFinal: true);

    expect(controller.transcript, 'gasté veinte mil en lavado');
    expect(controller.draft!.description, isNot('Gasté veinte mil'));
    expect(controller.status, VoiceCaptureStatus.ready);
  });

  test('un parcial tardío no pisa el resultado', () async {
    await controller.start();
    recognizer.say('gasté veinte mil', isFinal: true);

    recognizer.say('gasté', isFinal: false);

    expect(controller.transcript, 'gasté veinte mil');
  });

  test('permiso negado deja el error y no abre el micrófono', () async {
    recognizer.initFailure = SpeechFailure.permissionDenied;

    await controller.start();

    expect(controller.status, VoiceCaptureStatus.error);
    expect(controller.failure, SpeechFailure.permissionDenied);
    expect(recognizer.isListening, isFalse);
  });

  test('un error mientras escucha corta la captura', () async {
    await controller.start();

    recognizer.fail(SpeechFailure.failed);

    expect(controller.status, VoiceCaptureStatus.error);
    expect(controller.failure, SpeechFailure.failed);
    expect(controller.isActive, isFalse);
  });

  test('cancel apaga el micrófono y descarta lo capturado', () async {
    await controller.start();
    recognizer.say('gasté diez mil', isFinal: true);

    await controller.cancel();

    expect(recognizer.cancelCalls, 1);
    expect(recognizer.isListening, isFalse);
    expect(controller.status, VoiceCaptureStatus.idle);
    expect(controller.transcript, isEmpty);
    expect(controller.draft, isNull);
  });

  test(
    'tras cancelar, los eventos de la escucha anterior se ignoran',
    () async {
      await controller.start();
      await controller.cancel();

      recognizer.say('gasté diez mil', isFinal: true);

      expect(controller.status, VoiceCaptureStatus.idle);
      expect(controller.draft, isNull);
    },
  );

  test('release apaga el micrófono pero conserva lo interpretado', () async {
    await controller.start();
    recognizer.say('gasté diez mil en peaje', isFinal: true);

    await controller.release();
    recognizer.say('otra cosa', isFinal: true); // evento tardío

    expect(recognizer.cancelCalls, 1);
    expect(controller.status, VoiceCaptureStatus.ready);
    expect(controller.draft!.amount, 10000);
    expect(controller.transcript, 'gasté diez mil en peaje');
    expect(controller.canSave, isTrue);
  });

  test('una captura nueva descarta la anterior', () async {
    await controller.start();
    recognizer.say('gasté diez mil', isFinal: true);

    await controller.start();

    expect(controller.status, VoiceCaptureStatus.listening);
    expect(controller.draft, isNull);
    expect(controller.transcript, isEmpty);
  });

  test('descartar el controlador apaga el micrófono', () async {
    final ownRecognizer = FakeSpeechRecognizer();
    final own = VoiceCaptureController(recognizer: ownRecognizer);
    await own.start();
    expect(ownRecognizer.isListening, isTrue);

    own.dispose();

    expect(ownRecognizer.cancelCalls, 1);
    expect(ownRecognizer.isListening, isFalse);
  });

  group('vehículo', () {
    test('usa el vehículo actual si la frase no nombra ninguno', () async {
      await controller.start();

      recognizer.say('gasolina 60 mil', isFinal: true);

      expect(controller.selectedCarId, 'c1');
    });

    test('cambia al vehículo que nombra la frase', () async {
      await controller.start();

      recognizer.say('aceite 120 mil la Duster', isFinal: true);

      expect(controller.selectedCarId, 'c2');
    });

    test('el usuario puede elegir otro vehículo', () async {
      await controller.start();
      recognizer.say('gasolina 60 mil', isFinal: true);

      controller.setCarId('c2');

      expect(controller.selectedCarId, 'c2');
      expect(controller.toTransaction(userId: 'u1').carId, 'c2');
    });

    test('sin vehículo elegido no se puede guardar', () async {
      final noCar = VoiceCaptureController(
        recognizer: recognizer,
        now: () => now,
      );
      await noCar.start();
      recognizer.say('gasolina 60 mil', isFinal: true);

      expect(noCar.canSave, isFalse);
      noCar.dispose();
    });
  });

  group('edición de lo entendido', () {
    Future<void> hear(String phrase) async {
      await controller.start();
      recognizer.say(phrase, isFinal: true);
    }

    test('cambiar el tipo actualiza el borrador', () async {
      await hear('gasolina 60 mil');
      expect(controller.draft!.type, TransactionType.expense);

      controller.setType(TransactionType.income);

      expect(controller.draft!.type, TransactionType.income);
      expect(controller.draft!.category, isNull);
      expect(controller.canSave, isTrue);
    });

    test('cambiar la categoría', () async {
      await hear('gasolina 60 mil');

      controller.setCategory(TransactionCategory.maintenance);

      expect(controller.draft!.category, TransactionCategory.maintenance);
    });

    test('cambiar la fecha', () async {
      await hear('gasolina 60 mil');

      controller.setDate(DateTime(2026, 11, 1));

      expect(controller.draft!.date, DateTime(2026, 11, 1));
    });

    test('corregir el monto habilita guardar', () async {
      await hear('gasté en gasolina');
      expect(controller.canSave, isFalse);

      controller.setAmount(55000);

      expect(controller.canSave, isTrue);
      expect(controller.toTransaction(userId: 'u1').amount, 55000);
    });

    test('un monto en cero o vacío no se puede guardar', () async {
      await hear('gasolina 60 mil');

      controller.setAmount(0);
      expect(controller.canSave, isFalse);
      controller.setAmount(null);
      expect(controller.canSave, isFalse);
    });

    test('las ediciones notifican a la interfaz', () async {
      await hear('gasolina 60 mil');
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setType(TransactionType.income);
      controller.setAmount(1000);
      controller.setDate(DateTime(2026, 11, 2));
      controller.setCategory(TransactionCategory.other);
      controller.setCarId('c2');

      expect(notifications, 5);
    });

    test('editar sin resultado no hace nada', () {
      controller.setType(TransactionType.income);
      controller.setAmount(10);

      expect(controller.draft, isNull);
    });

    test('toTransaction guarda lo editado', () async {
      await hear('gasolina 60 mil');
      controller
        ..setType(TransactionType.income)
        ..setAmount(150000)
        ..setCarId('c2');

      final t = controller.toTransaction(userId: 'u1');

      expect(t.type, TransactionType.income);
      expect(t.amount, 150000);
      expect(t.carId, 'c2');
      expect(t.category, isNull);
      expect(t.userId, 'u1');
    });
  });

  group('nivel de sonido y cronómetro', () {
    test('el volumen del micrófono se refleja mientras se escucha', () async {
      await controller.start();

      recognizer.level(0.7);

      expect(controller.soundLevel.value, 0.7);
    });

    test('el volumen se limita a 0..1 y vuelve a 0 al terminar', () async {
      await controller.start();
      recognizer.level(3);
      expect(controller.soundLevel.value, 1);

      recognizer.say('gasolina 60 mil', isFinal: true);

      expect(controller.soundLevel.value, 0);
    });

    test('el volumen tardío se ignora tras terminar', () async {
      await controller.start();
      recognizer.say('gasolina 60 mil', isFinal: true);

      recognizer.level(0.9);

      expect(controller.soundLevel.value, 0);
    });

    test(
      'el cronómetro corre mientras escucha y se congela al terminar',
      () async {
        var clock = DateTime(2026, 11, 10, 12);
        final timed = VoiceCaptureController(
          recognizer: recognizer,
          now: () => clock,
          initialCarId: 'c1',
        );
        await timed.start();

        clock = clock.add(const Duration(seconds: 7));
        expect(timed.elapsed, const Duration(seconds: 7));

        recognizer.say('gasolina 60 mil', isFinal: true);
        clock = clock.add(const Duration(seconds: 30));

        expect(timed.elapsed, const Duration(seconds: 7));
        timed.dispose();
      },
    );

    test('empezar de nuevo reinicia el cronómetro', () async {
      var clock = DateTime(2026, 11, 10, 12);
      final timed = VoiceCaptureController(
        recognizer: recognizer,
        now: () => clock,
      );
      await timed.start();
      clock = clock.add(const Duration(seconds: 9));
      recognizer.say('gasolina 60 mil', isFinal: true);

      await timed.start();

      expect(timed.elapsed, Duration.zero);
      timed.dispose();
    });
  });
}
