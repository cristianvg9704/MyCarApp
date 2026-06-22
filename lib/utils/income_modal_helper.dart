import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/add_income_screen.dart';
import '../providers/car_provider.dart';

class IncomeModalHelper {
  /// Muestra un modal desde abajo para agregar un ingreso
  static Future<bool?> showAddIncomeModal(BuildContext context, {String? carId}) {
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
                  color: Colors.grey[300],
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
                      'Agregar Ingreso',
                      style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
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
                  child: AddIncomeScreen(initialCarId: carId, inModal: true),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((success) {
      // Recargar vehículos si se agregó un ingreso exitosamente
      if (success == true) {
        // Usar las referencias guardadas en lugar del context
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Ingreso guardado exitosamente'),
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
    });
  }
}
