import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/car_transaction.dart';
import '../screens/add_transaction_screen.dart';
import '../providers/car_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/speech_recognizer.dart';
import '../widgets/voice_entry_sheet.dart';
import 'my_car_colors.dart';
import 'my_car_palette.dart';

class TransactionModalHelper {
  /// Muestra un modal desde abajo para registrar un ingreso o un egreso
  static Future<bool?> showAddTransactionModal(
    BuildContext context, {
    String? carId,
    TransactionType initialType = TransactionType.income,
  }) {
    // Guardar una referencia al contexto original para usar después
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final carProvider = Provider.of<CarProvider>(context, listen: false);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (sheetContext, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(modalContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registrar Movimiento',
                      style: Theme.of(modalContext).textTheme.titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(modalContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: AddTransactionScreen(
                    initialCarId: carId,
                    initialType: initialType,
                    inModal: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((success) => _afterSave(success, scaffoldMessenger, carProvider));
  }

  /// Hoja para registrar un movimiento solo con la voz (Listo → Escuchando →
  /// Revisar y guardar), sin el formulario. Devuelve `true` si se guardó algo.
  ///
  /// Al guardar muestra "Gasto guardado" / "Ingreso guardado" con **Deshacer**
  /// y llama a [onChanged] (también si se deshace) para que la pantalla que
  /// abrió la hoja refresque sus datos. Si el usuario prefiere registrar a
  /// mano, abre el formulario completo.
  static Future<bool?> showVoiceTransactionSheet(
    BuildContext context, {
    required String carId,
    VoidCallback? onChanged,
    @visibleForTesting SpeechRecognizer? speechRecognizer,
    @visibleForTesting String? Function()? currentUserId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    final transactions = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );

    final outcome = await showModalBottomSheet<VoiceEntryOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: MyCarColors.scrim,
      builder: (_) => VoiceEntrySheet(
        carId: carId,
        speechRecognizer: speechRecognizer,
        currentUserId: currentUserId,
      ),
    );

    switch (outcome) {
      case VoiceEntrySaved(:final transactionId, :final type):
        void refresh() {
          carProvider.loadCars();
          onChanged?.call();
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              type == TransactionType.expense
                  ? 'Gasto guardado'
                  : 'Ingreso guardado',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () async {
                try {
                  await transactions.delete(transactionId);
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('No se pudo deshacer')),
                  );
                  return;
                }
                refresh();
              },
            ),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
        return true;
      case VoiceEntryManual():
        if (!context.mounted) return null;
        final saved = await showAddTransactionModal(context, carId: carId);
        if (saved == true) onChanged?.call();
        return saved;
      case null:
        return null;
    }
  }

  /// Avisa y recarga los vehículos si se guardó un movimiento.
  static bool? _afterSave(
    bool? success,
    ScaffoldMessengerState scaffoldMessenger,
    CarProvider carProvider,
  ) {
    if (success == true) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Movimiento guardado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      // Recargar vehículos para actualizar los totales
      WidgetsBinding.instance.addPostFrameCallback((_) {
        carProvider.loadCars();
      });
    }
    return success;
  }
}
