import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/supabase_config.dart';
import '../models/car_transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/voice_capture_controller.dart';
import '../services/speech_recognizer.dart';
import '../services/voice_transaction_parser.dart';
import '../utils/currency_formatter.dart';
import '../utils/my_car_colors.dart';

/// Hoja compacta para registrar un movimiento solo con la voz.
///
/// No muestra el formulario de ingresos/egresos: solo el texto que se va
/// entendiendo y el movimiento interpretado. El usuario lo revisa y pulsa
/// Guardar (la voz puede equivocarse); no se guarda nada automáticamente.
/// Se cierra con `true` si guardó.
class VoiceTransactionSheet extends StatefulWidget {
  final String carId;

  /// Reconocimiento de voz. Por defecto el del dispositivo; inyectable para
  /// tests.
  final SpeechRecognizer? speechRecognizer;

  /// Devuelve el id del usuario autenticado. Inyectable para tests.
  final String? Function()? currentUserId;

  /// Empieza a escuchar al abrirse.
  final bool autoStart;

  const VoiceTransactionSheet({
    super.key,
    required this.carId,
    this.speechRecognizer,
    this.currentUserId,
    this.autoStart = true,
  });

  @override
  State<VoiceTransactionSheet> createState() => _VoiceTransactionSheetState();
}

class _VoiceTransactionSheetState extends State<VoiceTransactionSheet> {
  late final VoiceCaptureController _controller = VoiceCaptureController(
    recognizer: widget.speechRecognizer ?? DeviceSpeechRecognizer(),
  );
  bool _isSaving = false;
  String? _saveError;

  String? _userId() => widget.currentUserId != null
      ? widget.currentUserId!()
      : SupabaseConfig.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.start();
      });
    }
  }

  @override
  void dispose() {
    // Apaga el micrófono si la hoja se cierra de cualquier forma.
    _controller.dispose();
    super.dispose();
  }

  void _onMicPressed() {
    if (_controller.isListening) {
      _controller.stop();
    } else if (!_controller.isActive) {
      setState(() => _saveError = null);
      _controller.start();
    }
  }

  Future<void> _save() async {
    final draft = _controller.draft;
    if (_isSaving || draft == null || !_controller.canSave) return;

    final userId = _userId();
    if (userId == null || userId.isEmpty) {
      setState(() => _saveError = 'Error: Usuario no autenticado');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    // El micrófono se apaga antes de guardar (la captura ya terminó) sin
    // perder lo entendido, por si el guardado falla y hay que reintentar.
    await _controller.release();
    if (!mounted) return;

    try {
      await Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).add(draft.toTransaction(userId: userId, carId: widget.carId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Error al guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registrar por voz',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('voice_close_button'),
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildMic(),
              const SizedBox(height: 16),
              _buildTranscript(),
              if (_controller.status == VoiceCaptureStatus.ready &&
                  _controller.draft != null) ...[
                const SizedBox(height: 16),
                _DraftSummary(draft: _controller.draft!),
              ],
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _saveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: MyCarColors.error),
                ),
              ],
              const SizedBox(height: 20),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  String get _statusLabel {
    switch (_controller.status) {
      case VoiceCaptureStatus.idle:
        return 'Toca el micrófono y habla';
      case VoiceCaptureStatus.listening:
        return 'Escuchando… toca para terminar';
      case VoiceCaptureStatus.processing:
        return 'Procesando…';
      case VoiceCaptureStatus.ready:
        return _controller.canSave
            ? 'Esto fue lo que entendí'
            : 'No entendí el monto. Intenta de nuevo.';
      case VoiceCaptureStatus.noSpeech:
        return 'No te escuché. Intenta de nuevo.';
      case VoiceCaptureStatus.error:
        return speechFailureMessage(
          _controller.failure ?? SpeechFailure.failed,
        );
    }
  }

  Widget _buildMic() {
    final listening = _controller.isListening;
    return Column(
      children: [
        Semantics(
          button: true,
          label: listening ? 'Terminar de escuchar' : 'Hablar',
          child: Material(
            color: listening ? MyCarColors.error : MyCarColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('voice_mic_button'),
              customBorder: const CircleBorder(),
              onTap: _isSaving ? null : _onMicPressed,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _statusLabel,
          key: const Key('voice_status_label'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _controller.status == VoiceCaptureStatus.error
                ? MyCarColors.error
                : MyCarColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTranscript() {
    final text = _controller.transcript;
    if (text.isEmpty) {
      if (_controller.isActive) return const SizedBox.shrink();
      return const Text(
        'Ej: "gasté cincuenta mil en gasolina ayer"',
        textAlign: TextAlign.center,
        style: TextStyle(color: MyCarColors.textTertiary, fontSize: 12),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyCarColors.primaryLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '“$text”',
        key: const Key('voice_transcript'),
        style: const TextStyle(
          color: MyCarColors.textPrimary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildActions() {
    final canRetry = !_controller.isActive && !_isSaving;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('voice_retry_button'),
            onPressed: canRetry ? _onMicPressed : null,
            child: const Text('Hablar de nuevo'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: const Key('voice_save_button'),
            onPressed: _controller.canSave && !_isSaving ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar'),
          ),
        ),
      ],
    );
  }
}

/// Resumen del movimiento interpretado (solo lectura).
class _DraftSummary extends StatelessWidget {
  final VoiceTransactionDraft draft;

  const _DraftSummary({required this.draft});

  @override
  Widget build(BuildContext context) {
    final isExpense = draft.type == TransactionType.expense;
    final color = isExpense ? MyCarColors.error : MyCarColors.success;
    final amount = draft.amount;

    return Container(
      key: const Key('voice_draft_summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MyCarColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  draft.type.label,
                  key: const Key('voice_draft_type'),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                amount == null ? 'Sin monto' : CurrencyFormatter.format(amount),
                key: const Key('voice_draft_amount'),
                style: TextStyle(
                  color: amount == null ? MyCarColors.error : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(
            Icons.notes_rounded,
            draft.description.isEmpty ? draft.type.label : draft.description,
          ),
          if (draft.category != null && isExpense)
            _row(Icons.sell_outlined, draft.category!.label),
          _row(
            Icons.calendar_today_outlined,
            DateFormat('dd/MM/yyyy').format(draft.date),
          ),
          if (draft.liters != null)
            _row(Icons.local_gas_station_outlined, '${_n(draft.liters!)} L'),
          if (draft.odometerKm != null)
            _row(Icons.speed_rounded, '${_n(draft.odometerKm!)} km'),
        ],
      ),
    );
  }

  static String _n(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: MyCarColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: MyCarColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}
