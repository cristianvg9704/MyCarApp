import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Motivo por el que no se pudo usar el reconocimiento de voz.
enum SpeechFailure {
  /// El usuario negó el permiso de micrófono o de reconocimiento de voz.
  permissionDenied,

  /// El dispositivo no tiene un servicio de reconocimiento de voz.
  unavailable,

  /// Ocurrió un error durante la escucha (red, audio, etc.).
  failed,
}

/// Mensaje en español para mostrar al usuario según el motivo del fallo.
String speechFailureMessage(SpeechFailure failure) {
  switch (failure) {
    case SpeechFailure.permissionDenied:
      return 'Activa el micrófono y el reconocimiento de voz para MyCar en Ajustes.';
    case SpeechFailure.unavailable:
      return 'Este dispositivo no tiene reconocimiento de voz disponible.';
    case SpeechFailure.failed:
      return 'No se pudo reconocer la voz. Intenta de nuevo.';
  }
}

/// Reconocimiento de voz a texto. Abstracción sobre el motor del dispositivo
/// para poder probar las pantallas con un reconocedor falso.
abstract class SpeechRecognizer {
  bool get isListening;

  /// Prepara el motor y pide permisos. Devuelve null si todo está listo, o el
  /// motivo del fallo.
  Future<SpeechFailure?> initialize();

  /// Empieza a escuchar. [onResult] se llama con resultados parciales y con el
  /// final (`isFinal == true`). [onDone] se llama cuando la escucha termina;
  /// [onError] si falla a mitad de camino.
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    VoidCallback? onDone,
    void Function(SpeechFailure failure)? onError,
  });

  /// Termina la escucha y entrega el resultado final.
  Future<void> stop();

  /// Termina la escucha descartando el resultado.
  Future<void> cancel();
}

/// Implementación con el reconocimiento nativo de iOS y Android
/// (`speech_to_text`). Prefiere el español de Colombia y, si no está
/// disponible, cualquier español.
class DeviceSpeechRecognizer implements SpeechRecognizer {
  final SpeechToText _speech = SpeechToText();
  String? _localeId;
  void Function(SpeechFailure failure)? _onError;
  VoidCallback? _onDone;
  SpeechFailure? _initFailure;
  bool _initialized = false;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<SpeechFailure?> initialize() async {
    if (_initialized) return _speech.isAvailable ? null : _initFailure;

    final available = await _speech.initialize(
      onError: _handleError,
      onStatus: _handleStatus,
    );
    _initialized = true;

    if (!available) {
      // Sin permiso concedido el motor reporta "no disponible"
      _initFailure = (await _speech.hasPermission)
          ? SpeechFailure.unavailable
          : SpeechFailure.permissionDenied;
      return _initFailure;
    }

    _localeId = await _pickSpanishLocale();
    return null;
  }

  Future<String?> _pickSpanishLocale() async {
    final locales = await _speech.locales();
    String normalize(String id) => id.replaceAll('-', '_');
    for (final prefix in const ['es_CO', 'es_']) {
      for (final locale in locales) {
        if (normalize(locale.localeId).startsWith(prefix)) {
          return locale.localeId;
        }
      }
    }
    return null;
  }

  @override
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    VoidCallback? onDone,
    void Function(SpeechFailure failure)? onError,
  }) async {
    _onError = onError;
    _onDone = onDone;
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  void _handleStatus(String status) {
    if (status == 'done' || status == 'notListening') _onDone?.call();
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint(
      'Speech error: ${error.errorMsg} (permanent: ${error.permanent})',
    );
    // "no match" y "speech timeout" son normales cuando el usuario no dice nada
    if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      return;
    }
    _onError?.call(
      error.errorMsg.contains('permission')
          ? SpeechFailure.permissionDenied
          : SpeechFailure.failed,
    );
  }
}
