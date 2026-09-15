import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_recommendation.dart';
import '../models/mileage_reading.dart';
import '../models/trip_log.dart';
import '../providers/mileage_provider.dart';
import '../providers/trip_provider.dart';
import '../utils/my_car_colors.dart';

class CarMileageTab extends StatefulWidget {
  final String carId;
  final DateTime? purchaseDate;

  const CarMileageTab({
    super.key,
    required this.carId,
    this.purchaseDate,
  });

  @override
  State<CarMileageTab> createState() => _CarMileageTabState();
}

class _CarMileageTabState extends State<CarMileageTab> {
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MileageProvider>().loadForCar(
            widget.carId,
            baselineDate: widget.purchaseDate,
          );
      context.read<TripProvider>().loadTripsForCar(widget.carId);
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _syncDurationTimer(TripProvider tripProvider) {
    if (tripProvider.isTracking && _durationTimer == null) {
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!tripProvider.isTracking && _durationTimer != null) {
      _durationTimer?.cancel();
      _durationTimer = null;
    }
  }

  Future<void> _startTrip(TripProvider tripProvider) async {
    final success = await tripProvider.startTrip(widget.carId);
    if (!mounted) return;

    if (success) {
      _syncDurationTimer(tripProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viaje iniciado. Puedes minimizar la app o apagar la pantalla.'),
          backgroundColor: MyCarColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
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
  }

  Future<void> _stopTrip(
    TripProvider tripProvider,
    MileageProvider mileageProvider,
  ) async {
    final km = tripProvider.liveDistanceKm;
    if (km <= 0) {
      await tripProvider.stopTrip(
        mileageProvider: mileageProvider,
        updateOdometer: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje detenido (sin distancia registrada)')),
        );
      }
      _syncDurationTimer(tripProvider);
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

    if (!mounted) return;

    final trip = await tripProvider.stopTrip(
      mileageProvider: mileageProvider,
      updateOdometer: updateOdometer == true,
    );

    _syncDurationTimer(tripProvider);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _showAddReadingDialog(MileageProvider provider) async {
    final odometerController = TextEditingController(
      text: provider.currentOdometerKm?.toStringAsFixed(0) ?? '',
    );
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar kilometraje'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: odometerController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Odómetro (km) *',
                    hintText: 'Ej: 45000',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de lectura'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    final km = double.tryParse(odometerController.text.trim());
    if (km == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un kilometraje válido')),
      );
      return;
    }

    final success = await provider.addMileageReading(
      carId: widget.carId,
      odometerKm: km,
      readingDate: selectedDate,
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Kilometraje registrado'
              : provider.errorMessage ?? 'Error al registrar',
        ),
        backgroundColor: success ? MyCarColors.success : MyCarColors.error,
      ),
    );
  }

  Future<void> _markAsDone(
    MileageProvider provider,
    MaintenanceRecommendation rec,
  ) async {
    final current = provider.currentOdometerKm;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero registra el kilometraje actual'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar ${rec.title}'),
        content: Text(
          '¿Confirmas que realizaste este servicio a ${current.toStringAsFixed(0)} km?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await provider.markMaintenanceDone(
      carId: widget.carId,
      serviceType: rec.serviceType,
      odometerKm: current,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '${rec.title} registrado' : 'Error al registrar servicio',
        ),
        backgroundColor: success ? MyCarColors.success : MyCarColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MileageProvider, TripProvider>(
      builder: (context, provider, tripProvider, _) {
        _syncDurationTimer(tripProvider);

        _syncDurationTimer(tripProvider);

        if (provider.isLoading && provider.readings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.errorMessage != null && provider.readings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: MyCarColors.warning, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No se pudo cargar el kilometraje',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Asegúrate de ejecutar la migración SQL en Supabase (docs/SUPABASE_MILEAGE_MIGRATION.md)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MyCarColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTripCard(context, tripProvider, provider),
              const SizedBox(height: 16),
              _buildSummaryCard(context, provider),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recomendaciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : () => _showAddReadingDialog(provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar km'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (provider.currentOdometerKm == null)
                _buildEmptyState(context, provider)
              else
                ...provider.recommendations.map(
                  (rec) => _buildRecommendationCard(context, provider, rec),
                ),
              if (provider.readings.length > 1) ...[
                const SizedBox(height: 20),
                Text(
                  'Historial reciente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                ...provider.readings.take(5).map(_buildReadingTile),
              ],
              if (tripProvider.trips.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Viajes GPS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                ...tripProvider.trips.take(5).map(_buildTripTile),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    TripProvider tripProvider,
    MileageProvider mileageProvider,
  ) {
    final isActive =
        tripProvider.isTracking && tripProvider.liveTrip?.carId == widget.carId;
    final isOtherCarActive =
        tripProvider.isTracking && tripProvider.liveTrip?.carId != widget.carId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? MyCarColors.primaryLight
            : MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? MyCarColors.primary : MyCarColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.gps_fixed : Icons.route,
                color: isActive ? MyCarColors.primary : MyCarColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isActive ? 'Viaje en curso' : 'Registro automático GPS',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isActive)
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
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'Funciona en segundo plano con pantalla apagada'
                : 'Pulsa Empezar antes de conducir. MyCar calculará los km con GPS.',
            style: TextStyle(
              color: MyCarColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTripStat(
                  'Distancia',
                  '${tripProvider.liveDistanceKm.toStringAsFixed(1)} km',
                ),
                _buildTripStat(
                  'Duración',
                  _formatDuration(tripProvider.liveDuration),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (isOtherCarActive)
            Text(
              'Hay un viaje activo en otro vehículo. Deténlo primero.',
              style: TextStyle(color: MyCarColors.warning, fontSize: 12),
            )
          else
            FilledButton.icon(
              onPressed: tripProvider.isLoading
                  ? null
                  : isActive
                      ? () => _stopTrip(tripProvider, mileageProvider)
                      : () => _startTrip(tripProvider),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isActive ? MyCarColors.error : MyCarColors.primary,
              ),
              icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
              label: Text(isActive ? 'Detener viaje' : 'Empezar viaje'),
            ),
        ],
      ),
    );
  }

  Widget _buildTripStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: MyCarColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: MyCarColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTripTile(TripLog trip) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: MyCarColors.secondaryLight,
        child: Icon(Icons.route, color: MyCarColors.secondary, size: 20),
      ),
      title: Text('${trip.distanceKm.toStringAsFixed(1)} km'),
      subtitle: Text(
        '${DateFormat('dd/MM/yyyy HH:mm').format(trip.startedAt)} · ${_formatDuration(Duration(seconds: trip.durationSeconds))}',
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, MileageProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: MyCarColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kilometraje actual',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            provider.currentOdometerKm != null
                ? '${NumberFormat('#,##0').format(provider.currentOdometerKm)} km'
                : 'Sin registrar',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (provider.trackedKm > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${NumberFormat('#,##0').format(provider.trackedKm)} km recorridos registrados',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, MileageProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyCarColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.speed, size: 48, color: MyCarColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'Registra el odómetro de tu vehículo para recibir recomendaciones de mantenimiento',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showAddReadingDialog(provider),
            icon: const Icon(Icons.add),
            label: const Text('Registrar primer kilometraje'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    MileageProvider provider,
    MaintenanceRecommendation rec,
  ) {
    final color = switch (rec.status) {
      MaintenanceStatus.overdue => MyCarColors.error,
      MaintenanceStatus.soon => MyCarColors.warning,
      MaintenanceStatus.ok => MyCarColors.success,
    };

    final progress = (rec.kmSinceService / rec.intervalKm).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForService(rec.serviceType), color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rec.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rec.statusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rec.description,
            style: TextStyle(color: MyCarColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: MyCarColors.border,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.isOverdue
                ? 'Vencido hace ${rec.kmSinceService.toStringAsFixed(0)} km (cada ${rec.intervalKm} km)'
                : 'Faltan ${rec.kmRemaining.toStringAsFixed(0)} km · cada ${rec.intervalKm} km o ${rec.intervalMonths} meses',
            style: TextStyle(color: MyCarColors.textSecondary, fontSize: 12),
          ),
          if (rec.status != MaintenanceStatus.ok) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: provider.isLoading
                    ? null
                    : () => _markAsDone(provider, rec),
                child: const Text('Marcar como hecho'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingTile(MileageReading reading) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: MyCarColors.primaryLight,
        child: Icon(Icons.speed, color: MyCarColors.primary, size: 20),
      ),
      title: Text('${NumberFormat('#,##0').format(reading.odometerKm)} km'),
      subtitle: Text(DateFormat('dd/MM/yyyy').format(reading.readingDate)),
    );
  }

  IconData _iconForService(String type) {
    return switch (type) {
      'oil_change' => Icons.oil_barrel_outlined,
      'tire_rotation' || 'tire_change' => Icons.tire_repair_outlined,
      'air_filter' => Icons.air_outlined,
      'brake_check' => Icons.car_crash_outlined,
      'coolant' => Icons.water_drop_outlined,
      _ => Icons.build_outlined,
    };
  }
}
