import 'package:flutter/foundation.dart';
import '../models/car_transaction.dart';
import '../services/speech_recognizer.dart';
import '../services/voice_transaction_parser.dart';

/// Etapas de una captura por voz.
enum VoiceCaptureStatus {
  /// Sin escuchar y sin resultado (estado inicial o tras cancelar).
  idle,

  /// El micrófono está abierto.
  listening,

  /// El usuario terminó de hablar y se espera el texto final.
  processing,

  /// Hay un movimiento interpretado ([VoiceCaptureController.draft]).
  ready,

  /// Se terminó de escuchar pero no se entendió nada.
  noSpeech,

  /// No se pudo usar el reconocimiento ([VoiceCaptureController.failure]).
  error,
}

/// Estado de una captura por voz: escucha, transcripción en vivo e
/// interpretación del movimiento. Es lógica pura (sin widgets) para poder
/// probarla con un reconocedor falso.
///
/// Garantiza que el micrófono queda apagado cuando la captura termina, se
/// cancela o se descarta el controlador, y que los eventos tardíos de una
/// escucha anterior no pisan el estado actual.
class VoiceCaptureController extends ChangeNotifier {
  final SpeechRecognizer _recognizer;
  final DateTime Function() _now;
  final TransactionType _defaultType;

  VoiceCaptureStatus _status = VoiceCaptureStatus.idle;
  String _transcript = '';
  VoiceTransactionDraft? _draft;
  SpeechFailure? _failure;
  int _session = 0;
  bool _disposed = false;

  VoiceCaptureController({
    required SpeechRecognizer recognizer,
    DateTime Function()? now,
    TransactionType defaultType = TransactionType.expense,
  }) : _recognizer = recognizer,
       _now = now ?? DateTime.now,
       _defaultType = defaultType;

  VoiceCaptureStatus get status => _status;
  String get transcript => _transcript;
  VoiceTransactionDraft? get draft => _draft;
  SpeechFailure? get failure => _failure;

  bool get isListening => _status == VoiceCaptureStatus.listening;

  /// El micrófono está abierto o se está cerrando.
  bool get isActive =>
      _status == VoiceCaptureStatus.listening ||
      _status == VoiceCaptureStatus.processing;

  /// Se puede guardar: hay un movimiento interpretado con monto.
  bool get canSave =>
      _status == VoiceCaptureStatus.ready && (_draft?.hasAmount ?? false);

  /// Empieza una captura nueva descartando la anterior.
  Future<void> start() async {
    if (isActive) return;
    final session = ++_session;
    _transcript = '';
    _draft = null;
    _failure = null;

    final failure = await _recognizer.initialize();
    if (_isStale(session)) return;
    if (failure != null) {
      _fail(failure);
      return;
    }

    _setStatus(VoiceCaptureStatus.listening);
    await _recognizer.start(
      onResult: (text, isFinal) {
        // Un resultado final tardío (después de "terminado") aún corrige lo
        // interpretado; los parciales tardíos se ignoran.
        if (_isStale(session) || (!isActive && !isFinal)) return;
        _transcript = text;
        if (isFinal) {
          _finish();
        } else {
          notifyListeners();
        }
      },
      onDone: () {
        if (_isStale(session) || !isActive) return;
        _finish();
      },
      onError: (failure) {
        if (_isStale(session) || !isActive) return;
        _fail(failure);
      },
    );
  }

  /// El usuario terminó de hablar: se cierra el micrófono y se interpreta lo
  /// dicho. La interfaz sale de "escuchando" de inmediato.
  Future<void> stop() async {
    if (!isListening) return;
    _setStatus(VoiceCaptureStatus.processing);
    await _recognizer.stop();
  }

  /// Apaga el micrófono y descarta lo capturado.
  Future<void> cancel() async {
    _session++;
    _transcript = '';
    _draft = null;
    _failure = null;
    await _recognizer.cancel();
    _setStatus(VoiceCaptureStatus.idle);
  }

  /// Apaga el micrófono **sin** descartar lo interpretado y ignora cualquier
  /// evento tardío del motor. Se usa antes de guardar: así nada llega después y
  /// el resultado sigue disponible si el guardado falla y hay que reintentar.
  Future<void> release() async {
    _session++;
    await _recognizer.cancel();
  }

  void _finish() {
    if (_transcript.trim().isEmpty) {
      _setStatus(VoiceCaptureStatus.noSpeech);
      return;
    }
    _draft = VoiceTransactionParser.parse(
      _transcript,
      now: _now(),
      defaultType: _defaultType,
    );
    _setStatus(VoiceCaptureStatus.ready);
  }

  void _fail(SpeechFailure failure) {
    _failure = failure;
    _setStatus(VoiceCaptureStatus.error);
  }

  bool _isStale(int session) => _disposed || session != _session;

  void _setStatus(VoiceCaptureStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _recognizer.cancel();
    }
    super.dispose();
  }
}
