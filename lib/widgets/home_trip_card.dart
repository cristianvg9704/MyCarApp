import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/car.dart';
import '../providers/car_provider.dart';
import '../providers/mileage_provider.dart';
import '../providers/trip_provider.dart';
import '../utils/my_car_colors.dart';
import '../utils/trip_format.dart';
import 'trip_actions.dart';

/// Acceso rápido para iniciar (y detener) un viaje GPS desde el inicio, sin
/// entrar al detalle del vehículo.
///
/// - Sin vehículos no se muestra.
/// - Con un solo vehículo inicia el viaje de ese vehículo.
/// - Con varios pregunta con cuál.
/// - Con un viaje en curso muestra el vehículo, la distancia y la duración en
///   vivo, y permite detenerlo; tocar la tarjeta abre el detalle del vehículo.
class HomeTripCard extends StatefulWidget {
  const HomeTripCard({super.key});

  @override
  State<HomeTripCard> createState() => _HomeTripCardState();
}

class _HomeTripCardState extends State<HomeTripCard> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Refresca la duración cada segundo solo mientras hay un viaje activo.
  void _syncTicker(bool isTracking) {
    if (isTracking && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!isTracking && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _start(List<Car> cars) async {
    final tripProvider = context.read<TripProvider>();
    final car = cars.length == 1 ? cars.first : await _chooseCar(cars);
    if (car?.id == null || !mounted) return;
    await TripActions.start(context, tripProvider, car!.id!);
  }

  Future<Car?> _chooseCar(List<Car> cars) {
    return showModalBottomSheet<Car>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '¿Con qué vehículo vas a viajar?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final car in cars)
              ListTile(
                leading: const Icon(
                  Icons.directions_car_outlined,
                  color: MyCarColors.primary,
                ),
                title: Text('${car.brand} ${car.model}'),
                subtitle: car.plateNumber == null
                    ? null
                    : Text(car.plateNumber!),
                onTap: () => Navigator.of(sheetContext).pop(car),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _stop(String carId) async {
    final tripProvider = context.read<TripProvider>();
    final mileageProvider = context.read<MileageProvider>();
    // El odómetro actual sale del historial del vehículo del viaje.
    await mileageProvider.loadForCar(carId);
    if (!mounted) return;
    await TripActions.stop(context, tripProvider, mileageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarProvider>().cars;
    // Sin vehículos no hay viaje que iniciar (y el inicio ya muestra su
    // estado vacío).
    if (cars.isEmpty) return const SizedBox.shrink();

    final tripProvider = context.watch<TripProvider>();
    final live = tripProvider.liveTrip;
    final isActive = tripProvider.isTracking && live != null;

    // El timer se (des)activa después del frame, no dentro de build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker(isActive);
    });

    return isActive
        ? _buildActive(context, tripProvider, cars, live.carId)
        : _buildIdle(context, tripProvider, cars);
  }

  Widget _buildIdle(
    BuildContext context,
    TripProvider tripProvider,
    List<Car> cars,
  ) {
    return _CardShell(
      key: const Key('home_trip_card_idle'),
      highlighted: false,
      child: Row(
        children: [
          const _TripIcon(active: false),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar un viaje',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: MyCarColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Mide los km con GPS, incluso con la pantalla apagada.',
                  style: TextStyle(
                    color: MyCarColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('home_trip_start_button'),
            onPressed: tripProvider.isLoading ? null : () => _start(cars),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Iniciar'),
          ),
        ],
      ),
    );
  }

  Widget _buildActive(
    BuildContext context,
    TripProvider tripProvider,
    List<Car> cars,
    String carId,
  ) {
    final matches = cars.where((c) => c.id == carId);
    final car = matches.isEmpty ? null : matches.first;
    final name = car == null ? 'Vehículo' : '${car.brand} ${car.model}';

    return _CardShell(
      key: const Key('home_trip_card_active'),
      highlighted: true,
      onTap: () => context.go('/car-detail?carId=$carId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _TripIcon(active: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Viaje en curso',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: MyCarColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MyCarColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: MyCarColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                label: 'Distancia',
                value: '${tripProvider.liveDistanceKm.toStringAsFixed(1)} km',
                valueKey: const Key('home_trip_distance'),
              ),
              _Stat(
                label: 'Duración',
                value: formatTripDuration(tripProvider.liveDuration),
                valueKey: const Key('home_trip_duration'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('home_trip_stop_button'),
            onPressed: tripProvider.isLoading ? null : () => _stop(carId),
            style: FilledButton.styleFrom(backgroundColor: MyCarColors.error),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Detener viaje'),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final bool highlighted;
  final VoidCallback? onTap;
  final Widget child;

  const _CardShell({
    super.key,
    required this.highlighted,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? MyCarColors.primaryLight : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? MyCarColors.primary : MyCarColors.border,
              width: highlighted ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TripIcon extends StatelessWidget {
  final bool active;

  const _TripIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: active
            ? MyCarColors.primary
            : MyCarColors.primaryLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        active ? Icons.gps_fixed : Icons.route_rounded,
        color: active ? Colors.white : MyCarColors.primary,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;

  const _Stat({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MyCarColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: MyCarColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
