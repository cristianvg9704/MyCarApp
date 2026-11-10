import 'package:flutter/foundation.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';

/// Reconocedor de voz falso para tests: el test "habla" con [say] y simula
/// fallos con [fail].
class FakeSpeechRecognizer implements SpeechRecognizer {
  SpeechFailure? initFailure;
  int initializeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool _listening = false;
  String _lastText = '';
  void Function(String text, bool isFinal)? _onResult;
  VoidCallback? _onDone;
  void Function(SpeechFailure failure)? _onError;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechFailure?> initialize() async {
    initializeCalls++;
    return initFailure;
  }

  @override
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    VoidCallback? onDone,
    void Function(SpeechFailure failure)? onError,
  }) async {
    _listening = true;
    _onResult = onResult;
    _onDone = onDone;
    _onError = onError;
  }

  /// Simula lo que dice el usuario.
  void say(String text, {bool isFinal = false}) {
    _lastText = text;
    _onResult?.call(text, isFinal);
    if (isFinal) {
      _listening = false;
      _onDone?.call();
    }
  }

  /// El motor avisa "terminado" sin haber entregado un resultado final.
  void finishWithoutFinalResult() {
    _listening = false;
    _onDone?.call();
  }

  void fail(SpeechFailure failure) => _onError?.call(failure);

  @override
  Future<void> stop() async {
    stopCalls++;
    say(_lastText, isFinal: true);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _listening = false;
  }
}
