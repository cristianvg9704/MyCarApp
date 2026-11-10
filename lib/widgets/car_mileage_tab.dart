import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/maintenance_recommendation.dart';
import '../models/mileage_reading.dart';
import '../models/trip_log.dart';
import '../providers/mileage_provider.dart';
import '../providers/trip_provider.dart';
import '../services/maintenance_recommendation_service.dart';
import '../services/usage_analytics.dart';
import '../utils/currency_formatter.dart';
import '../utils/my_car_colors.dart';
import '../utils/trip_format.dart';
import 'trip_actions.dart';

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
      context.read<MileageProvider>().loadForCar(widget.carId);
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
    final started = await TripActions.start(
      context,
      tripProvider,
      widget.carId,
    );
    if (started && mounted) _syncDurationTimer(tripProvider);
  }

  Future<void> _stopTrip(
    TripProvider tripProvider,
    MileageProvider mileageProvider,
  ) async {
    await TripActions.stop(context, tripProvider, mileageProvider);
    if (mounted) _syncDurationTimer(tripProvider);
  }

  String _formatDuration(Duration d) => formatTripDuration(d);

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

  Future<void> _showAddServiceDialog(MileageProvider provider) async {
    final odometerController = TextEditingController(
      text: provider.currentOdometerKm?.toStringAsFixed(0) ?? '',
    );
    String serviceType =
        MaintenanceRecommendationService.serviceTypeLabels.keys.first;
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar servicio'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  decoration: const InputDecoration(labelText: 'Servicio *'),
                  items: [
                    for (final entry in MaintenanceRecommendationService
                        .serviceTypeLabels
                        .entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => serviceType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: odometerController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Odómetro al servicio (km) *',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha del servicio'),
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

    final success = await provider.addMaintenanceLog(
      carId: widget.carId,
      serviceType: serviceType,
      odometerKm: km,
      serviceDate: selectedDate,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${MaintenanceRecommendationService.labelFor(serviceType)} registrado'
              : provider.errorMessage ?? 'Error al registrar servicio',
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
              if (provider.insights.hasAnyData) ...[
                const SizedBox(height: 16),
                _buildInsightsCard(context, provider.insights),
              ],
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
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: provider.isLoading
                              ? null
                              : () => _showAddReadingDialog(provider),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Registrar km'),
                        ),
                        TextButton.icon(
                          onPressed: provider.isLoading
                              ? null
                              : () => _showAddServiceDialog(provider),
                          icon: const Icon(Icons.build_outlined, size: 18),
                          label: const Text('Servicio'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (provider.currentOdometerKm == null)
                _buildEmptyState(context, provider)
              else if (provider.recommendations.isEmpty)
                _buildNoServicesState(context, provider)
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

  Widget _buildInsightsCard(BuildContext context, UsageInsights insights) {
    final numberFormat = NumberFormat('#,##0');
    final lines = <(IconData, String)>[
      if (insights.kmPerDay != null)
        (
          Icons.trending_up,
          'Uso: ${insights.kmPerDay!.toStringAsFixed(1)} km/día '
              '(~${numberFormat.format(insights.kmPerMonth)} km/mes)',
        ),
      if (insights.fuelEfficiency != null)
        (
          Icons.local_gas_station_outlined,
          'Rendimiento: ${insights.fuelEfficiency!.kmPerLiter.toStringAsFixed(1)} km/L '
              '(${insights.fuelEfficiency!.samples} tanqueadas)',
        ),
      if (insights.costPerKm != null)
        (
          Icons.payments_outlined,
          'Costo por km: ${CurrencyFormatter.format(insights.costPerKm!)}',
        ),
      if (insights.averageMaintenanceCost != null)
        (
          Icons.build_outlined,
          'Mantenimiento promedio: '
              '${CurrencyFormatter.format(insights.averageMaintenanceCost!)} '
              '(${insights.maintenanceCount})',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyCarColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu uso (según tu historial)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: MyCarColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: MyCarColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoServicesState(BuildContext context, MileageProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyCarColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.build_outlined, size: 48, color: MyCarColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'Registra tus servicios (aceite, frenos, llantas...). Con dos '
            'registros del mismo servicio calculamos tu intervalo real.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showAddServiceDialog(provider),
            icon: const Icon(Icons.add),
            label: const Text('Registrar servicio'),
          ),
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
            'Registra el odómetro y tus servicios para recibir recomendaciones basadas en tu propio historial',
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
      MaintenanceStatus.needsHistory => MyCarColors.textSecondary,
    };

    final progress = rec.progress;

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
            _lastServiceText(rec),
            style: TextStyle(color: MyCarColors.textSecondary, fontSize: 13),
          ),
          if (progress != null) ...[
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
          ],
          const SizedBox(height: 8),
          Text(
            _recommendationDetail(rec),
            style: TextStyle(color: MyCarColors.textSecondary, fontSize: 12),
          ),
          if (rec.isOverdue || rec.isSoon) ...[
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

  String _lastServiceText(MaintenanceRecommendation rec) {
    final date = DateFormat('dd/MM/yyyy').format(rec.lastServiceDate);
    final km = NumberFormat('#,##0').format(rec.lastServiceKm);
    return 'Último: $date a $km km · hace ${rec.daysSinceService} días, '
        '${NumberFormat('#,##0').format(rec.kmSinceService)} km';
  }

  String _recommendationDetail(MaintenanceRecommendation rec) {
    if (!rec.hasInterval) {
      return 'Registra este servicio una vez más para calcular tu intervalo '
          'a partir de tu historial.';
    }

    final parts = <String>[
      if (rec.intervalKm != null)
        '${NumberFormat('#,##0').format(rec.intervalKm)} km',
      if (rec.intervalDays != null) '${rec.intervalDays} días',
    ];
    final interval = 'Tu intervalo: cada ${parts.join(' o ')} '
        '(${rec.recordCount} registros)';

    final String status;
    if (rec.isOverdue) {
      status = 'Vencido. ';
    } else {
      final remaining = <String>[
        if (rec.kmRemaining != null)
          '${NumberFormat('#,##0').format(rec.kmRemaining)} km',
        if (rec.daysRemaining != null) '${rec.daysRemaining} días',
      ];
      status = 'Faltan ${remaining.join(' o ')}. ';
    }

    final due = rec.estimatedDueDate;
    final estimate = due == null || rec.isOverdue
        ? ''
        : ' · Estimado: ${DateFormat('dd/MM/yyyy').format(due)}';
    return '$status$interval$estimate';
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
