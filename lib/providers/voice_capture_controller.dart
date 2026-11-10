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

/// Estado de una captura por voz: escucha, transcripción en vivo,
/// interpretación y edición del movimiento. Es lógica pura (sin widgets) para
/// poder probarla con un reconocedor falso.
///
/// Garantiza que el micrófono queda apagado cuando la captura termina, se
/// cancela o se descarta el controlador, y que los eventos tardíos de una
/// escucha anterior no pisan el estado actual.
class VoiceCaptureController extends ChangeNotifier {
  final SpeechRecognizer _recognizer;
  final DateTime Function() _now;
  final TransactionType _defaultType;
  final List<VoiceVehicle> _vehicles;

  VoiceCaptureStatus _status = VoiceCaptureStatus.idle;
  String _transcript = '';
  VoiceTransactionDraft? _draft;
  SpeechFailure? _failure;
  String? _selectedCarId;
  DateTime? _listeningSince;
  Duration _frozenElapsed = Duration.zero;
  int _session = 0;
  bool _disposed = false;

  /// Volumen del micrófono (0 a 1) mientras se escucha. Aparte del resto del
  /// estado porque cambia muchas veces por segundo.
  final ValueNotifier<double> soundLevel = ValueNotifier<double>(0);

  VoiceCaptureController({
    required SpeechRecognizer recognizer,
    DateTime Function()? now,
    TransactionType defaultType = TransactionType.expense,
    List<VoiceVehicle> vehicles = const [],
    String? initialCarId,
  }) : _recognizer = recognizer,
       _now = now ?? DateTime.now,
       _defaultType = defaultType,
       _vehicles = vehicles,
       _selectedCarId = initialCarId;

  VoiceCaptureStatus get status => _status;
  String get transcript => _transcript;
  VoiceTransactionDraft? get draft => _draft;
  SpeechFailure? get failure => _failure;

  /// Vehículo al que se guardará: el actual, el que nombró la frase o el que
  /// eligió el usuario.
  String? get selectedCarId => _selectedCarId;

  bool get isListening => _status == VoiceCaptureStatus.listening;

  /// El micrófono está abierto o se está cerrando.
  bool get isActive =>
      _status == VoiceCaptureStatus.listening ||
      _status == VoiceCaptureStatus.processing;

  /// Tiempo escuchando; se congela cuando termina la escucha.
  Duration get elapsed => isListening && _listeningSince != null
      ? _now().difference(_listeningSince!)
      : _frozenElapsed;

  /// Se puede guardar: hay un movimiento interpretado con monto mayor a cero y
  /// un vehículo elegido.
  bool get canSave =>
      _status == VoiceCaptureStatus.ready &&
      (_draft?.amount ?? 0) > 0 &&
      _selectedCarId != null;

  /// Empieza una captura nueva descartando la anterior.
  Future<void> start() async {
    if (isActive) return;
    final session = ++_session;
    _transcript = '';
    _draft = null;
    _failure = null;
    _frozenElapsed = Duration.zero;
    soundLevel.value = 0;

    final failure = await _recognizer.initialize();
    if (_isStale(session)) return;
    if (failure != null) {
      _fail(failure);
      return;
    }

    _listeningSince = _now();
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
      onSoundLevel: (level) {
        if (_isStale(session) || !isListening) return;
        soundLevel.value = level.clamp(0.0, 1.0);
      },
    );
  }

  /// El usuario terminó de hablar: se cierra el micrófono y se interpreta lo
  /// dicho. La interfaz sale de "escuchando" de inmediato.
  Future<void> stop() async {
    if (!isListening) return;
    _freezeClock();
    _setStatus(VoiceCaptureStatus.processing);
    await _recognizer.stop();
  }

  /// Apaga el micrófono y descarta lo capturado.
  Future<void> cancel() async {
    _session++;
    _transcript = '';
    _draft = null;
    _failure = null;
    _frozenElapsed = Duration.zero;
    soundLevel.value = 0;
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

  // --- Edición del movimiento interpretado --------------------------------

  void setType(TransactionType type) => _edit((d) => d.withType(type));

  /// `null` deja el monto vacío (no se podrá guardar).
  void setAmount(double? amount) => _edit((d) => d.withAmount(amount));

  void setCategory(TransactionCategory category) =>
      _edit((d) => d.withCategory(category));

  void setDate(DateTime date) => _edit((d) => d.withDate(date));

  void setCarId(String carId) {
    if (_selectedCarId == carId) return;
    _selectedCarId = carId;
    notifyListeners();
  }

  void _edit(VoiceTransactionDraft Function(VoiceTransactionDraft) change) {
    final current = _draft;
    if (current == null || _disposed) return;
    _draft = change(current);
    notifyListeners();
  }

  /// Movimiento listo para guardar. Requiere [canSave].
  CarTransaction toTransaction({required String userId}) {
    assert(canSave, 'No se puede guardar sin monto, vehículo o resultado');
    return _draft!.toTransaction(userId: userId, carId: _selectedCarId!);
  }

  // --- Interno -------------------------------------------------------------

  void _finish() {
    _freezeClock();
    soundLevel.value = 0;
    if (_transcript.trim().isEmpty) {
      _setStatus(VoiceCaptureStatus.noSpeech);
      return;
    }
    final draft = VoiceTransactionParser.parse(
      _transcript,
      now: _now(),
      defaultType: _defaultType,
      vehicles: _vehicles,
    );
    _draft = draft;
    if (draft.mentionedCarId != null) _selectedCarId = draft.mentionedCarId;
    _setStatus(VoiceCaptureStatus.ready);
  }

  void _freezeClock() {
    if (_listeningSince != null) {
      _frozenElapsed = _now().difference(_listeningSince!);
      _listeningSince = null;
    }
  }

  void _fail(SpeechFailure failure) {
    _freezeClock();
    soundLevel.value = 0;
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
      soundLevel.dispose();
    }
    super.dispose();
  }
}
