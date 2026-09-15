import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/add_vehicle_screen.dart';
import '../screens/edit_vehicle_screen.dart';
import '../providers/car_provider.dart';
import '../models/car.dart';

class VehicleModalHelper {
  /// Muestra un modal desde abajo para agregar un vehículo
  static Future<bool?> showAddVehicleModal(BuildContext context) {
    debugPrint('VehicleModalHelper: Mostrando modal de agregar vehículo');
    // Guardar una referencia al contexto original para usar después
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (modalContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(modalContext).bottom;

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetContext, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          'Agregar Vehículo',
                          style: Theme.of(modalContext)
                              .textTheme
                              .titleLarge
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 24),
                      child: const AddVehicleScreen(inModal: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((success) {
      // Recargar vehículos si se agregó un vehículo exitosamente
      if (success == true) {
        // Usar las referencias guardadas en lugar del context
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Vehículo guardado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Recargar vehículos
        WidgetsBinding.instance.addPostFrameCallback((_) {
          carProvider.loadCars();
        });
      }
      return success;
    });
  }

  /// Muestra un modal desde abajo para editar un vehículo
  static Future<bool?> showEditVehicleModal(BuildContext context, Car car) {
    debugPrint('VehicleModalHelper: Mostrando modal de editar vehículo');
    // Guardar una referencia al contexto original para usar después
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (modalContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(modalContext).bottom;

        return AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetContext, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          'Editar Vehículo',
                          style: Theme.of(modalContext)
                              .textTheme
                              .titleLarge
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 24),
                      child: EditVehicleScreen(car: car, inModal: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((success) {
      // Recargar vehículos si se actualizó un vehículo exitosamente
      if (success == true) {
        // Usar las referencias guardadas en lugar del context
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Vehículo actualizado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Recargar vehículos
        WidgetsBinding.instance.addPostFrameCallback((_) {
          carProvider.loadCars();
        });
      }
      return success;
    });
  }
}
