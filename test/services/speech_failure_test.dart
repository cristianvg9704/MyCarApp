import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';

void main() {
  group('failureForErrorMessage', () {
    test('permisos', () {
      expect(
        DeviceSpeechRecognizer.failureForErrorMessage('error_permission'),
        SpeechFailure.permissionDenied,
      );
    });

    test('sin conexión', () {
      expect(
        DeviceSpeechRecognizer.failureForErrorMessage('error_network'),
        SpeechFailure.network,
      );
      expect(
        DeviceSpeechRecognizer.failureForErrorMessage('error_network_timeout'),
        SpeechFailure.network,
      );
    });

    test('cualquier otro error es un fallo genérico', () {
      expect(
        DeviceSpeechRecognizer.failureForErrorMessage('error_audio'),
        SpeechFailure.failed,
      );
    });
  });

  test('cada fallo tiene un mensaje en español', () {
    for (final failure in SpeechFailure.values) {
      expect(speechFailureMessage(failure), isNotEmpty);
    }
    expect(
      speechFailureMessage(SpeechFailure.network),
      contains('internet'),
    );
  });
}
