import 'package:flutter/material.dart';
import '../providers/mileage_provider.dart';
import '../providers/trip_provider.dart';
import '../utils/my_car_colors.dart';

/// Iniciar y detener un viaje con sus avisos al usuario. Lo comparten la
/// pestaña Kilometraje y la tarjeta de viaje del inicio, para que ambas se
/// comporten igual.
class TripActions {
  TripActions._();

  /// Inicia el viaje de [carId]; avisa si arrancó o por qué no.
  static Future<bool> start(
    BuildContext context,
    TripProvider tripProvider,
    String carId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final started = await tripProvider.startTrip(carId);

    if (started) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Viaje iniciado. Puedes minimizar la app o apagar la pantalla.',
          ),
          backgroundColor: MyCarColors.success,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tripProvider.errorMessage ??
                'Activa el GPS y concede permiso de ubicación "Siempre"',
          ),
          backgroundColor: MyCarColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    return started;
  }

  /// Detiene el viaje activo. Si recorrió distancia, pregunta si se actualiza
  /// el odómetro. [mileageProvider] debe tener cargado el vehículo del viaje.
  static Future<void> stop(
    BuildContext context,
    TripProvider tripProvider,
    MileageProvider mileageProvider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final km = tripProvider.liveDistanceKm;

    if (km <= 0) {
      await tripProvider.stopTrip(
        mileageProvider: mileageProvider,
        updateOdometer: false,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Viaje detenido (sin distancia registrada)'),
        ),
      );
      return;
    }

    final current = mileageProvider.currentOdometerKm;
    final newOdometer = (current ?? 0) + km;

    final updateOdometer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar viaje'),
        content: Text(
          current != null
              ? 'Recorriste ${km.toStringAsFixed(1)} km.\n\n¿Actualizar odómetro de ${current.toStringAsFixed(0)} km a ${newOdometer.toStringAsFixed(0)} km?'
              : 'Recorriste ${km.toStringAsFixed(1)} km.\n\n¿Registrar ${newOdometer.toStringAsFixed(0)} km como odómetro inicial?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Solo guardar viaje'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Actualizar odómetro'),
          ),
        ],
      ),
    );

    final trip = await tripProvider.stopTrip(
      mileageProvider: mileageProvider,
      updateOdometer: updateOdometer == true,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          trip != null
              ? 'Viaje guardado: ${km.toStringAsFixed(1)} km'
              : 'Error al guardar el viaje',
        ),
        backgroundColor: trip != null ? MyCarColors.success : MyCarColors.error,
      ),
    );
  }
}
