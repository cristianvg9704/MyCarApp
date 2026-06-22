import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/alert_provider.dart';
import '../providers/car_provider.dart';
import '../models/alert.dart';
import '../models/car.dart';
import '../utils/my_car_colors.dart';

class AlertsListScreen extends StatefulWidget {
  const AlertsListScreen({super.key});

  @override
  State<AlertsListScreen> createState() => _AlertsListScreenState();
}

class _AlertsListScreenState extends State<AlertsListScreen> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alertProvider = Provider.of<AlertProvider>(context, listen: false);
      final carProvider = Provider.of<CarProvider>(context, listen: false);
      
      // Cargar alertas y vehículos
      alertProvider.loadAlerts();
      if (carProvider.cars.isEmpty) {
        carProvider.loadCars();
      }
      _hasInitialized = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar alertas cuando la pantalla vuelve a estar visible después de la inicialización
    // Esto asegura que las alertas se actualicen cuando se vuelve de agregar una nueva
    if (_hasInitialized && mounted) {
      // Guardar referencia al Provider antes de la operación asíncrona
      final alertProvider = Provider.of<AlertProvider>(context, listen: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          alertProvider.loadAlerts();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyCarColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Alertas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyCarColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add,
                  color: MyCarColors.primary,
                  size: 22,
                ),
              ),
              onPressed: () async {
                if (!mounted) return;
                final navigatorContext = context;
                await navigatorContext.push('/add-alert');
                // Recargar alertas cuando se vuelve de agregar alerta
                if (mounted) {
                  final alertProvider = Provider.of<AlertProvider>(navigatorContext, listen: false);
                  await alertProvider.loadAlerts();
                }
              },
              tooltip: 'Agregar alerta',
            ),
          ),
        ],
      ),
      body: Consumer2<AlertProvider, CarProvider>(
        builder: (context, alertProvider, carProvider, child) {
          if (alertProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (carProvider.cars.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: MyCarColors.primaryLight.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_outlined,
                        size: 72,
                        color: MyCarColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'No hay vehículos',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MyCarColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Agrega un vehículo para comenzar\na crear alertas',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MyCarColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Verificar si no hay alertas en general (sin filtrar)
          if (alertProvider.allAlerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: MyCarColors.primaryLight.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 72,
                        color: MyCarColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'No hay alertas',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MyCarColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Crea alertas para recordatorios\nde mantenimiento y pagos',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MyCarColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    FilledButton.icon(
                      onPressed: () async {
                        await context.push('/add-alert');
                        // Recargar alertas cuando se vuelve de agregar alerta
                        if (mounted) {
                          final alertProvider = Provider.of<AlertProvider>(context, listen: false);
                          await alertProvider.loadAlerts();
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Crear Alerta',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: MyCarColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Filtros
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              context,
                              'Todas',
                              'all',
                              alertProvider.filter == 'all',
                              () => alertProvider.setFilter('all'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context,
                              'Pendientes',
                              'pending',
                              alertProvider.filter == 'pending',
                              () => alertProvider.setFilter('pending'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context,
                              'Próximas',
                              'upcoming',
                              alertProvider.filter == 'upcoming',
                              () => alertProvider.setFilter('upcoming'),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context,
                              'Completadas',
                              'completed',
                              alertProvider.filter == 'completed',
                              () => alertProvider.setFilter('completed'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista de alertas
              Expanded(
                child: alertProvider.alerts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getFilterIcon(alertProvider.filter),
                                size: 64,
                                color: MyCarColors.textTertiary,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _getFilterMessage(alertProvider.filter),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: MyCarColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getFilterSubmessage(alertProvider.filter),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: MyCarColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: alertProvider.alerts.length,
                        itemBuilder: (context, index) {
                          final alert = alertProvider.alerts[index];
                          final car = carProvider.cars.firstWhere(
                            (c) => c.id == alert.carId,
                            orElse: () => Car(
                              id: alert.carId,
                              userId: alert.userId,
                              brand: 'Vehículo',
                              model: '',
                              year: DateTime.now().year,
                            ),
                          );
                          return _buildAlertCard(context, alert, car, alertProvider);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: MyCarColors.primaryLight,
      checkmarkColor: MyCarColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? MyCarColors.primary : MyCarColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'upcoming':
        return Icons.schedule_outlined;
      case 'pending':
        return Icons.pending_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.filter_alt_outlined;
    }
  }

  String _getFilterMessage(String filter) {
    switch (filter) {
      case 'upcoming':
        return 'No hay alertas próximas';
      case 'pending':
        return 'No hay alertas pendientes';
      case 'completed':
        return 'No hay alertas completadas';
      default:
        return 'No hay alertas con este filtro';
    }
  }

  String _getFilterSubmessage(String filter) {
    switch (filter) {
      case 'upcoming':
        return 'No tienes alertas programadas para los próximos 7 días';
      case 'pending':
        return 'Todas tus alertas están completadas';
      case 'completed':
        return 'Aún no has completado ninguna alerta';
      default:
        return 'Intenta con otro filtro o crea una nueva alerta';
    }
  }

  Widget _buildAlertCard(
    BuildContext context,
    Alert alert,
    Car car,
    AlertProvider alertProvider,
  ) {
    final now = DateTime.now();
    // Normalizar fechas para comparar solo fechas (sin hora)
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final alertDateNormalized = DateTime(
      alert.alertDate.year,
      alert.alertDate.month,
      alert.alertDate.day,
    );
    
    final isOverdue = !alert.isCompleted && alertDateNormalized.isBefore(todayNormalized);
    final isToday = !alert.isCompleted && alertDateNormalized.isAtSameMomentAs(todayNormalized);
    final isUpcoming = !alert.isCompleted &&
        alertDateNormalized.isAfter(todayNormalized) &&
        alertDateNormalized.difference(todayNormalized).inDays <= 7;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (alert.isCompleted) {
      statusColor = MyCarColors.success;
      statusIcon = Icons.check_circle;
      statusText = 'Completada';
    } else if (isOverdue) {
      statusColor = MyCarColors.error;
      statusIcon = Icons.error_outline;
      statusText = 'Vencida';
    } else if (isToday) {
      statusColor = MyCarColors.warning;
      statusIcon = Icons.today;
      statusText = 'Hoy';
    } else if (isUpcoming) {
      statusColor = MyCarColors.primary;
      statusIcon = Icons.schedule;
      statusText = 'Próxima';
    } else {
      statusColor = MyCarColors.textSecondary;
      statusIcon = Icons.calendar_today;
      statusText = DateFormat('dd/MM/yyyy').format(alert.alertDate);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? MyCarColors.error.withValues(alpha: 0.3) : MyCarColors.border,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navegar a detalle o editar
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MyCarColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${car.brand} ${car.model}',
                          style: TextStyle(
                            fontSize: 13,
                            color: MyCarColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menú de acciones
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: MyCarColors.textSecondary,
                    ),
                    onSelected: (value) async {
                      // Guardar referencias antes de operaciones asíncronas
                      if (!mounted) return;
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      if (value == 'complete' && !alert.isCompleted) {
                        await alertProvider.completeAlert(alert.id!);
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Alerta marcada como completada'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else if (value == 'delete') {
                        // Mostrar diálogo de confirmación
                        if (!mounted) return;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Eliminar alerta'),
                            content: Text(
                              '¿Estás seguro de que quieres eliminar la alerta "${alert.title}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: MyCarColors.error,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmed == true && mounted) {
                          try {
                            await alertProvider.deleteAlert(alert.id!);
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Alerta eliminada exitosamente'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al eliminar alerta: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (!alert.isCompleted)
                        const PopupMenuItem<String>(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: MyCarColors.success),
                              SizedBox(width: 8),
                              Text('Marcar como completada'),
                            ],
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: MyCarColors.error),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (alert.description != null && alert.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  alert.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: MyCarColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: MyCarColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy').format(alert.alertDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: MyCarColors.textSecondary,
                    ),
                  ),
                  if (alert.isRecurring) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: MyCarColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRecurrenceText(alert),
                      style: TextStyle(
                        fontSize: 13,
                        color: MyCarColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRecurrenceText(Alert alert) {
    if (!alert.isRecurring) return '';
    
    switch (alert.recurrenceType) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        if (alert.recurrenceValue != null && alert.recurrenceValue! > 1) {
          return 'Cada ${alert.recurrenceValue} meses';
        }
        return 'Mensual';
      case 'yearly':
        return 'Anual';
      case 'custom_days':
        if (alert.recurrenceValue != null) {
          return 'Cada ${alert.recurrenceValue} días';
        }
        return 'Personalizada';
      default:
        return 'Recurrente';
    }
  }
}
