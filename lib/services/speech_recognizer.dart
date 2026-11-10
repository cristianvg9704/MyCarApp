import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Motivo por el que no se pudo usar el reconocimiento de voz.
enum SpeechFailure {
  /// El usuario negó el permiso de micrófono o de reconocimiento de voz.
  permissionDenied,

  /// El dispositivo no tiene un servicio de reconocimiento de voz.
  unavailable,

  /// El reconocimiento necesita conexión y no hay (o la red falló).
  network,

  /// Ocurrió un error durante la escucha (audio, etc.).
  failed,
}

/// Mensaje en español para mostrar al usuario según el motivo del fallo.
String speechFailureMessage(SpeechFailure failure) {
  switch (failure) {
    case SpeechFailure.permissionDenied:
      return 'Activa el micrófono y el reconocimiento de voz para MyCar en Ajustes.';
    case SpeechFailure.unavailable:
      return 'Este dispositivo no tiene reconocimiento de voz disponible.';
    case SpeechFailure.network:
      return 'Sin conexión: el reconocimiento de voz necesita internet.';
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
  /// [onError] si falla a mitad de camino. [onSoundLevel] recibe el volumen del
  /// micrófono normalizado de 0 a 1 (para animar la onda de audio).
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    VoidCallback? onDone,
    void Function(SpeechFailure failure)? onError,
    void Function(double level)? onSoundLevel,
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
    void Function(double level)? onSoundLevel,
  }) async {
    _onError = onError;
    _onDone = onDone;
    _minLevel = double.infinity;
    _maxLevel = double.negativeInfinity;
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      onSoundLevelChange: onSoundLevel == null
          ? null
          : (level) => onSoundLevel(_normalizeLevel(level)),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenFor: const Duration(seconds: 30),
        // ~2 s de silencio terminan la escucha.
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// El rango del nivel de sonido depende de la plataforma (iOS y Android lo
  /// reportan distinto), así que se normaliza con el mínimo y máximo vistos en
  /// esta escucha, con un rango mínimo para no amplificar el ruido de fondo.
  double _minLevel = double.infinity;
  double _maxLevel = double.negativeInfinity;

  double _normalizeLevel(double level) {
    if (level < _minLevel) _minLevel = level;
    if (level > _maxLevel) _maxLevel = level;
    final range = (_maxLevel - _minLevel).clamp(6.0, double.infinity);
    return ((level - _minLevel) / range).clamp(0.0, 1.0);
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
    _onError?.call(failureForErrorMessage(error.errorMsg));
  }

  /// Traduce el código de error del motor nativo a un [SpeechFailure].
  @visibleForTesting
  static SpeechFailure failureForErrorMessage(String errorMsg) {
    if (errorMsg.contains('permission')) return SpeechFailure.permissionDenied;
    if (errorMsg.contains('network')) return SpeechFailure.network;
    return SpeechFailure.failed;
  }
}
