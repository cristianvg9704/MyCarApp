import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/supabase_config.dart';
import '../models/car.dart';
import '../models/car_transaction.dart';
import '../providers/car_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/voice_capture_controller.dart';
import '../services/speech_recognizer.dart';
import '../services/voice_transaction_parser.dart';
import '../utils/currency_formatter.dart';
import '../utils/my_car_colors.dart';

/// Resultado con el que se cierra [VoiceEntrySheet].
sealed class VoiceEntryOutcome {
  const VoiceEntryOutcome();
}

/// Se guardó un movimiento (con su id, para poder deshacerlo).
class VoiceEntrySaved extends VoiceEntryOutcome {
  final String transactionId;
  final TransactionType type;

  const VoiceEntrySaved({required this.transactionId, required this.type});
}

/// El usuario prefirió registrar a mano (abrir el formulario).
class VoiceEntryManual extends VoiceEntryOutcome {
  const VoiceEntryManual();
}

/// Hoja para registrar un ingreso o un gasto con la voz, en 3 pasos:
/// **Listo → Escuchando → Revisar y guardar**.
///
/// No muestra el formulario de movimientos. El usuario siempre ve qué entendió
/// la app y puede corregir tipo, monto, categoría, vehículo y fecha antes de
/// guardar. No se guarda nada automáticamente (la voz puede equivocarse).
/// Se cierra con un [VoiceEntryOutcome], o con `null` si se descarta.
class VoiceEntrySheet extends StatefulWidget {
  /// Vehículo preseleccionado (el actual).
  final String carId;

  /// Reconocimiento de voz. Por defecto el del dispositivo; inyectable para
  /// tests.
  final SpeechRecognizer? speechRecognizer;

  /// Devuelve el id del usuario autenticado. Inyectable para tests.
  final String? Function()? currentUserId;

  /// Abre los ajustes del sistema (permisos). Inyectable para tests.
  final Future<void> Function()? openSettings;

  /// Vibración ligera al empezar y al terminar de escuchar. Inyectable.
  final Future<void> Function()? haptic;

  /// Reloj. Inyectable para tests.
  final DateTime Function()? now;

  const VoiceEntrySheet({
    super.key,
    required this.carId,
    this.speechRecognizer,
    this.currentUserId,
    this.openSettings,
    this.haptic,
    this.now,
  });

  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<VoiceEntrySheet> {
  static const _examples = [
    'Ingreso de 150 mil',
    'Gasolina 60 mil',
    'Cambio de aceite 120 mil ayer',
  ];

  late final List<Car> _cars = context.read<CarProvider>().cars;
  late final VoiceCaptureController _controller = VoiceCaptureController(
    recognizer: widget.speechRecognizer ?? DeviceSpeechRecognizer(),
    now: widget.now,
    initialCarId: widget.carId,
    vehicles: [
      for (final car in _cars)
        if (car.id != null)
          VoiceVehicle(id: car.id!, brand: car.brand, model: car.model),
    ],
  );
  VoiceCaptureStatus _previousStatus = VoiceCaptureStatus.idle;
  bool _isSaving = false;
  String? _saveError;

  DateTime get _today {
    final now = (widget.now ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  String? _userId() => widget.currentUserId != null
      ? widget.currentUserId!()
      : SupabaseConfig.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    // Apaga el micrófono si la hoja se cierra de cualquier forma.
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Vibración ligera al empezar y al terminar de escuchar.
  void _onControllerChanged() {
    final status = _controller.status;
    final started =
        status == VoiceCaptureStatus.listening &&
        _previousStatus != VoiceCaptureStatus.listening;
    final ended =
        _previousStatus == VoiceCaptureStatus.listening &&
        status != VoiceCaptureStatus.listening;
    _previousStatus = status;
    if (started || ended) _buzz();
  }

  Future<void> _buzz() async {
    try {
      await (widget.haptic ?? HapticFeedback.lightImpact)();
    } catch (_) {
      // La vibración es solo un detalle: nunca debe romper el flujo.
    }
  }

  Car? _carById(String? id) {
    for (final car in _cars) {
      if (car.id == id) return car;
    }
    return null;
  }

  String _carName(Car? car) =>
      car == null ? 'Elige un vehículo' : '${car.brand} ${car.model}';

  // --- Acciones -----------------------------------------------------------

  void _startListening() {
    setState(() => _saveError = null);
    _controller.start();
  }

  Future<void> _save() async {
    if (_isSaving || !_controller.canSave) return;

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
      final transaction = _controller.toTransaction(userId: userId);
      final id = await Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).addReturningId(transaction);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(VoiceEntrySaved(transactionId: id, type: transaction.type));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Error al guardar: $e';
      });
    }
  }

  void _useManualEntry() => Navigator.of(context).pop(const VoiceEntryManual());

  Future<void> _openSettings() async {
    try {
      await (widget.openSettings ?? openAppSettings)();
    } catch (_) {
      // Sin ajustes disponibles no hay nada más que hacer.
    }
  }

  // --- Selectores ---------------------------------------------------------

  Future<void> _pickVehicle() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                '¿A qué vehículo?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            for (final car in _cars)
              ListTile(
                key: Key('voice_vehicle_option_${car.id}'),
                minVerticalPadding: 12,
                leading: const Icon(
                  Icons.directions_car_outlined,
                  color: MyCarColors.primary,
                ),
                title: Text('${car.brand} ${car.model}'),
                subtitle: car.plateNumber == null
                    ? null
                    : Text(car.plateNumber!),
                trailing: car.id == _controller.selectedCarId
                    ? const Icon(Icons.check, color: MyCarColors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(car.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _controller.setCarId(picked);
  }

  Future<void> _pickCategory() async {
    final current = _controller.draft?.category;
    final picked = await showModalBottomSheet<TransactionCategory>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Categoría',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            for (final category in TransactionCategory.values)
              ListTile(
                key: Key('voice_category_option_${category.dbValue}'),
                minVerticalPadding: 12,
                leading: Icon(
                  _categoryIcon(category),
                  color: MyCarColors.primary,
                ),
                title: Text(category.label),
                trailing: category == current
                    ? const Icon(Icons.check, color: MyCarColors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(category),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _controller.setCategory(picked);
  }

  Future<void> _pickDate() async {
    final draft = _controller.draft;
    if (draft == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date.isAfter(_today) ? _today : draft.date,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked != null) _controller.setDate(picked);
  }

  Future<void> _editAmount() async {
    final current = _controller.draft?.amount;
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(initial: current),
    );
    if (amount != null) _controller.setAmount(amount);
  }

  // --- Construcción -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: MyCarColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 34 + bottom),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: MyCarColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(child: _buildForStatus(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForStatus(BuildContext context) {
    switch (_controller.status) {
      case VoiceCaptureStatus.idle:
        return _buildIdle();
      case VoiceCaptureStatus.listening:
      case VoiceCaptureStatus.processing:
        return _buildListening();
      case VoiceCaptureStatus.ready:
        return _buildReview();
      case VoiceCaptureStatus.noSpeech:
        return _buildProblem(
          title: 'No te escuché bien',
          message: 'Habla cerca del micrófono e intenta de nuevo.',
          retry: true,
        );
      case VoiceCaptureStatus.error:
        return _buildFailure(_controller.failure ?? SpeechFailure.failed);
    }
  }

  Widget _header(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: MyCarColors.textPrimary,
          ),
        ),
      ),
      trailing ??
          _roundIconButton(
            key: const Key('voice_close_button'),
            icon: Icons.close_rounded,
            label: 'Cerrar',
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
    ],
  );

  Widget _roundIconButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: MyCarColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        key: key,
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: MyCarColors.textPrimary, size: 22),
        ),
      ),
    ),
  );

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: MyCarColors.textLabel,
    ),
  );

  // --- Estado 1: Listo -----------------------------------------------------

  Widget _buildIdle() {
    final car = _carById(_controller.selectedCarId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Registrar por voz'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: _VehicleChip(
            name: _carName(car),
            onTap: _cars.isEmpty ? null : _pickVehicle,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: _MicButton(
            key: const Key('voice_mic_button'),
            listening: false,
            enabled: !_isSaving,
            onPressed: _startListening,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Toca el micrófono y habla',
          key: Key('voice_status_label'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MyCarColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel('Prueba decir'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final example in _examples)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MyCarColors.indigo50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '“$example”',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MyCarColors.primaryDark,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- Estado 2: Escuchando ------------------------------------------------

  Widget _buildListening() {
    final processing = _controller.status == VoiceCaptureStatus.processing;
    final transcript = _controller.transcript;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: processing
                    ? MyCarColors.textTertiary
                    : MyCarColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              processing ? 'Procesando…' : 'Escuchando…',
              key: const Key('voice_listening_label'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MyCarColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            _ElapsedClock(controller: _controller),
            const Spacer(),
            _roundIconButton(
              key: const Key('voice_cancel_button'),
              icon: Icons.close_rounded,
              label: 'Cancelar',
              onPressed: () => _controller.cancel(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Lo que entendí'),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MyCarColors.backgroundLight,
            border: Border.all(color: MyCarColors.borderLight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            transcript.isEmpty ? '…' : transcript,
            key: const Key('voice_transcript'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: transcript.isEmpty
                  ? MyCarColors.textTertiary
                  : MyCarColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Waveform(level: _controller.soundLevel),
        const SizedBox(height: 20),
        Center(
          child: _MicButton(
            key: const Key('voice_mic_button'),
            listening: true,
            enabled: !processing,
            onPressed: () => _controller.stop(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          processing ? 'Procesando…' : 'Toca para terminar',
          key: const Key('voice_status_label'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MyCarColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // --- Estado 3: Revisar y guardar ----------------------------------------

  Widget _buildReview() {
    final draft = _controller.draft!;
    final isExpense = draft.type == TransactionType.expense;
    final amount = draft.amount;
    final hasAmount = amount != null && amount > 0;
    final typeColor = isExpense ? MyCarColors.expense : MyCarColors.income;
    final amountText = hasAmount
        ? '${isExpense ? '−' : '+'}${CurrencyFormatter.format(amount)}'
        : r'$0';
    final car = _carById(_controller.selectedCarId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Revisa y guarda'),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.mic_none_rounded,
              size: 16,
              color: MyCarColors.textLabel,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '“${draft.transcript}”',
                key: const Key('voice_transcript'),
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: MyCarColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TypeSelector(selected: draft.type, onChanged: _controller.setType),
        const SizedBox(height: 20),
        Semantics(
          button: true,
          label: 'Editar monto',
          child: InkWell(
            key: const Key('voice_amount'),
            borderRadius: BorderRadius.circular(16),
            onTap: _editAmount,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    amountText,
                    key: const Key('voice_amount_text'),
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: hasAmount ? typeColor : MyCarColors.textTertiary,
                    ),
                  ),
                  Text(
                    hasAmount
                        ? 'Toca para editar'
                        : 'No entendí el monto. Toca para escribirlo.',
                    key: const Key('voice_amount_hint'),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasAmount
                          ? MyCarColors.textLabel
                          : MyCarColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isExpense)
          _ReviewRow(
            key: const Key('voice_row_category'),
            icon: _categoryIcon(draft.category ?? TransactionCategory.other),
            iconColor: MyCarColors.primary,
            iconBackground: MyCarColors.primaryLight,
            label: 'Categoría',
            value: (draft.category ?? TransactionCategory.other).label,
            onTap: _pickCategory,
          ),
        _ReviewRow(
          key: const Key('voice_row_vehicle'),
          icon: Icons.directions_car_outlined,
          iconColor: MyCarColors.secondary,
          iconBackground: MyCarColors.secondaryLight,
          label: 'Vehículo',
          value: _carName(car),
          onTap: _cars.isEmpty ? null : _pickVehicle,
        ),
        _ReviewRow(
          key: const Key('voice_row_date'),
          icon: Icons.calendar_today_outlined,
          iconColor: MyCarColors.warning,
          iconBackground: MyCarColors.warning.withValues(alpha: 0.15),
          label: 'Fecha',
          value: _dateLabel(draft.date),
          onTap: _pickDate,
          showDivider: false,
        ),
        if (_extraDetails(draft) case final extra?) ...[
          const SizedBox(height: 8),
          Text(
            extra,
            key: const Key('voice_extra_details'),
            style: const TextStyle(fontSize: 13, color: MyCarColors.textLabel),
          ),
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
        Row(
          children: [
            Expanded(
              child: _ActionButton.secondary(
                key: const Key('voice_retry_button'),
                label: 'Grabar de nuevo',
                onPressed: _isSaving ? null : _startListening,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton.primary(
                key: const Key('voice_save_button'),
                label: isExpense ? 'Guardar gasto' : 'Guardar ingreso',
                loading: _isSaving,
                onPressed: _controller.canSave && !_isSaving ? _save : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final diff = _today.difference(day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return DateFormat('dd/MM/yyyy').format(day);
  }

  /// Litros y kilometraje que la frase incluía (solo combustible/mantenimiento).
  String? _extraDetails(VoiceTransactionDraft draft) {
    if (draft.type != TransactionType.expense) return null;
    final category = draft.category;
    final parts = <String>[
      if (category == TransactionCategory.fuel && draft.liters != null)
        '${_number(draft.liters!)} L',
      if ((category == TransactionCategory.fuel ||
              category == TransactionCategory.maintenance) &&
          draft.odometerKm != null)
        '${_number(draft.odometerKm!)} km',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _number(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  // --- Errores y permisos --------------------------------------------------

  Widget _buildFailure(SpeechFailure failure) {
    switch (failure) {
      case SpeechFailure.permissionDenied:
        return _buildProblem(
          title: 'Necesito tu permiso',
          message:
              'MyCar usa el micrófono y el reconocimiento de voz para entender lo que dices y llenar el movimiento por ti. Actívalos en Ajustes para usar la voz.',
          openSettings: true,
        );
      case SpeechFailure.network:
        return _buildProblem(
          title: 'Sin conexión',
          message:
              'El reconocimiento de voz necesita internet. Revisa tu conexión e intenta de nuevo, o registra el movimiento a mano.',
          retry: true,
        );
      case SpeechFailure.unavailable:
        return _buildProblem(
          title: 'Voz no disponible',
          message:
              'Este dispositivo no tiene reconocimiento de voz disponible. Puedes registrar el movimiento a mano.',
        );
      case SpeechFailure.failed:
        return _buildProblem(
          title: 'No se pudo reconocer la voz',
          message: speechFailureMessage(SpeechFailure.failed),
          retry: true,
        );
    }
  }

  /// Panel de problema: explica qué pasó y ofrece la salida adecuada.
  Widget _buildProblem({
    required String title,
    required String message,
    bool retry = false,
    bool openSettings = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('Registrar por voz'),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: MyCarColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_off_rounded,
              size: 34,
              color: MyCarColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          key: const Key('voice_problem_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MyCarColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          key: const Key('voice_problem_message'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: MyCarColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        if (openSettings)
          _ActionButton.primary(
            key: const Key('voice_open_settings_button'),
            label: 'Abrir Ajustes',
            onPressed: _openSettings,
          ),
        if (retry)
          _ActionButton.primary(
            key: const Key('voice_retry_button'),
            label: 'Intentar de nuevo',
            onPressed: _startListening,
          ),
        const SizedBox(height: 12),
        _ActionButton.secondary(
          key: const Key('voice_manual_button'),
          label: 'Registrar a mano',
          onPressed: _useManualEntry,
        ),
      ],
    );
  }
}

IconData _categoryIcon(TransactionCategory category) {
  switch (category) {
    case TransactionCategory.fuel:
      return Icons.local_gas_station_outlined;
    case TransactionCategory.maintenance:
      return Icons.build_outlined;
    case TransactionCategory.other:
      return Icons.sell_outlined;
  }
}

// ============================================================================
// Piezas de la hoja
// ============================================================================

/// Chip con el vehículo elegido; al tocarlo abre el selector.
class _VehicleChip extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;

  const _VehicleChip({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vehículo: $name. Toca para cambiarlo',
      child: Material(
        color: MyCarColors.white,
        shape: StadiumBorder(side: BorderSide(color: MyCarColors.borderLight)),
        child: InkWell(
          key: const Key('voice_vehicle_chip'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 20,
                    color: MyCarColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MyCarColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: MyCarColors.textLabel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de micrófono: 104 px índigo dentro de un halo de 156 px. Al escuchar
/// muestra un cuadrado de "detener" y dos halos que laten.
class _MicButton extends StatefulWidget {
  final bool listening;
  final bool enabled;
  final VoidCallback onPressed;

  const _MicButton({
    super.key,
    required this.listening,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _ring(double phase) {
    final t = (_pulse.value + phase) % 1.0;
    return Transform.scale(
      scale: 1 + 0.45 * t,
      child: Container(
        width: 156,
        height: 156,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MyCarColors.primary.withValues(alpha: 0.18 * (1 - t)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.listening ? 'Terminar de escuchar' : 'Empezar a hablar',
      child: SizedBox(
        width: 204,
        height: 204,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.listening)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [_ring(0), _ring(0.5)],
                ),
              )
            else
              Container(
                width: 156,
                height: 156,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: MyCarColors.primaryLight,
                ),
              ),
            Material(
              color: widget.enabled
                  ? MyCarColors.primary
                  : MyCarColors.textTertiary,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: MyCarColors.primary.withValues(alpha: 0.4),
              child: InkWell(
                key: const Key('voice_mic_tap'),
                customBorder: const CircleBorder(),
                onTap: widget.enabled ? widget.onPressed : null,
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Center(
                    child: widget.listening
                        ? Container(
                            key: const Key('voice_stop_square'),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: MyCarColors.white,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          )
                        : const Icon(
                            Icons.mic_rounded,
                            color: MyCarColors.white,
                            size: 48,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cronómetro `m:ss` con cifras tabulares, mientras se escucha.
class _ElapsedClock extends StatefulWidget {
  final VoiceCaptureController controller;

  const _ElapsedClock({required this.controller});

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      format(widget.controller.elapsed),
      key: const Key('voice_elapsed'),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: MyCarColors.textLabel,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Onda de audio: [barCount] barras que se animan con el volumen del
/// micrófono; la historia reciente se desplaza hacia la izquierda.
class _Waveform extends StatefulWidget {
  static const barCount = 32;
  static const minHeight = 4.0;
  static const maxHeight = 44.0;

  final ValueListenable<double> level;

  const _Waveform({required this.level});

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform> {
  final List<double> _bars = List<double>.filled(
    _Waveform.barCount,
    0,
    growable: true,
  );
  Timer? _timer;
  double _smoothed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (!mounted) return;
      // Suavizado: la barra sube rápido y baja despacio.
      final target = widget.level.value;
      _smoothed = target > _smoothed
          ? _smoothed + (target - _smoothed) * 0.6
          : _smoothed + (target - _smoothed) * 0.3;
      setState(() {
        _bars
          ..removeAt(0)
          ..add(_smoothed);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onda de audio',
      excludeSemantics: true,
      child: SizedBox(
        key: const Key('voice_waveform'),
        height: _Waveform.maxHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _bars.length; i++)
              Container(
                key: Key('voice_wave_bar_$i'),
                width: 4,
                height:
                    _Waveform.minHeight +
                    _bars[i] * (_Waveform.maxHeight - _Waveform.minHeight),
                decoration: BoxDecoration(
                  color: MyCarColors.primary.withValues(
                    alpha: 0.35 + 0.65 * _bars[i],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Control segmentado Ingreso | Gasto.
class _TypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MyCarColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _option(
            key: const Key('voice_type_income'),
            type: TransactionType.income,
            label: 'Ingreso',
            color: MyCarColors.income,
          ),
          _option(
            key: const Key('voice_type_expense'),
            type: TransactionType.expense,
            label: 'Gasto',
            color: MyCarColors.expense,
          ),
        ],
      ),
    );
  }

  Widget _option({
    required Key key,
    required TransactionType type,
    required String label,
    required Color color,
  }) {
    final active = selected == type;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? MyCarColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: active ? color : MyCarColors.textLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila editable de la revisión: ícono en cuadro de color, label, valor y
/// chevron.
class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showDivider;

  const _ReviewRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value. Toca para cambiarlo',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: MyCarColors.borderLight),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MyCarColors.textLabel,
                      ),
                    ),
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MyCarColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MyCarColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón de acción de la hoja: alto 52, radio 14.
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;

  const _ActionButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  }) : primary = true;

  const _ActionButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : primary = false,
       loading = false;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const size = Size.fromHeight(52);
    const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: size,
          shape: shape,
          backgroundColor: MyCarColors.primary,
          foregroundColor: MyCarColors.white,
          textStyle: textStyle,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MyCarColors.white,
                ),
              )
            : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        shape: shape,
        foregroundColor: MyCarColors.textPrimary,
        side: const BorderSide(color: MyCarColors.border),
        textStyle: textStyle,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Diálogo para escribir el monto a mano.
class _AmountDialog extends StatefulWidget {
  final double? initial;

  const _AmountDialog({required this.initial});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial == null || widget.initial! <= 0
        ? ''
        : widget.initial!.toStringAsFixed(0),
  );
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _accept() {
    final value = parseAmount(_text.text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Ingresa un valor mayor a cero');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monto'),
      content: TextField(
        key: const Key('voice_amount_field'),
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(prefixText: r'$ ', errorText: _error),
        onSubmitted: (_) => _accept(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('voice_amount_accept'),
          onPressed: _accept,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
