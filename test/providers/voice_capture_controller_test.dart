import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/voice_capture_controller.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';

import '../helpers/fake_speech_recognizer.dart';

void main() {
  late FakeSpeechRecognizer recognizer;
  late VoiceCaptureController controller;
  final now = DateTime(2026, 11, 10, 12);

  setUp(() {
    recognizer = FakeSpeechRecognizer();
    controller = VoiceCaptureController(recognizer: recognizer, now: () => now);
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
}
