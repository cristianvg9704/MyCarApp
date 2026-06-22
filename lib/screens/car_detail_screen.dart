import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/car.dart';
import '../models/income.dart';
import '../services/database_helper.dart';
import '../providers/car_provider.dart';
import '../utils/my_car_colors.dart';
import '../utils/vehicle_modal_helper.dart';

class CarDetailScreen extends StatefulWidget {
  final String carId;

  const CarDetailScreen({super.key, required this.carId});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  Car? _car;
  bool _isLoading = true;
  List<Income> _incomes = [];
  bool _isLoadingIncomes = false;
  String _activeView = 'ingresos'; // 'ingresos' o 'graficos'
  String _selectedPeriod = 'all'; // '7', '30', 'all'

  @override
  void initState() {
    super.initState();
    _loadCar();
  }

  Future<void> _loadCar() async {
    try {
      final car = await DatabaseHelper.instance.getCar(widget.carId);
      if (mounted) {
        setState(() {
          _car = car;
          _isLoading = false;
        });
        if (_car != null) {
          _loadIncomes();
        }
      }
    } catch (e) {
      debugPrint('Error loading car: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadIncomes() async {
    if (_car?.id == null) return;
    setState(() {
      _isLoadingIncomes = true;
    });
    try {
      final incomes = await DatabaseHelper.instance.getIncomesByCar(_car!.id!);
      if (mounted) {
        setState(() {
          _incomes = incomes;
          _isLoadingIncomes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading incomes: $e');
      if (mounted) {
        setState(() {
          _isLoadingIncomes = false;
        });
      }
    }
  }

  Future<void> _deleteCar() async {
    if (_car?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Vehículo'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este vehículo? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<CarProvider>(
          context,
          listen: false,
        ).deleteCar(_car!.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehículo eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: MyCarColors.backgroundLight,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Text(
            'Detalle del Vehículo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_car == null) {
      return Scaffold(
        backgroundColor: MyCarColors.backgroundLight,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Text(
            'Detalle del Vehículo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 72, color: MyCarColors.error),
              const SizedBox(height: 24),
              Text(
                'Vehículo no encontrado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: MyCarColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/'),
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
                child: const Text(
                  'Volver al Inicio',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MyCarColors.backgroundLight,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          '${_car!.brand} ${_car!.model}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MyCarColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: MyCarColors.primary,
                  size: 20,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white.withValues(alpha: 0.95),
              elevation: 8,
              onSelected: (value) async {
                if (value == 'edit') {
                  if (_car != null) {
                    final success = await VehicleModalHelper.showEditVehicleModal(context, _car!);
                    if (success == true && mounted) {
                      // Recargar los datos del carro después de editar
                      _loadCar();
                    }
                  }
                } else if (value == 'delete') {
                  _deleteCar();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MyCarColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: MyCarColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Editar',
                          style: TextStyle(
                            color: MyCarColors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MyCarColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: MyCarColors.error,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Eliminar',
                          style: TextStyle(
                            color: MyCarColors.error,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 40,
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del vehículo con márgenes
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/car1 test.jpeg',
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 240,
                        decoration: BoxDecoration(
                          gradient: MyCarColors.primaryGradient,
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 80,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Contenedor con información
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Información del vehículo
                      _buildSimpleInfoRow('Año', '${_car!.year}'),
                      if (_car!.plateNumber != null) ...[
                        const SizedBox(height: 16),
                        _buildSimpleInfoRow('Placa', _car!.plateNumber!),
                      ],
                      if (_car!.color != null) ...[
                        const SizedBox(height: 16),
                        _buildSimpleInfoRow('Color', _car!.color!),
                      ],
                      if (_car!.purchaseDate != null) ...[
                        const SizedBox(height: 16),
                        _buildSimpleInfoRow(
                          'Fecha de Compra',
                          DateFormat('dd/MM/yyyy').format(_car!.purchaseDate!),
                        ),
                      ],
                      if (_car!.purchasePrice != null) ...[
                        const SizedBox(height: 16),
                        _buildSimpleInfoRow(
                          'Precio de Compra',
                          '\$${NumberFormat('#,##0.00').format(_car!.purchasePrice)}',
                        ),
                      ],
                      if (_car!.notes != null && _car!.notes!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'Notas',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: MyCarColors.textSecondary,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _car!.notes!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: MyCarColors.textPrimary,
                                height: 1.5,
                                fontSize: 15,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sección de ingresos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Botones de Ingresos y Gráficos
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _activeView = 'ingresos';
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _activeView == 'ingresos'
                                  ? MyCarColors.secondary
                                  : Colors.transparent,
                              foregroundColor: _activeView == 'ingresos'
                                  ? Colors.white
                                  : MyCarColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: _activeView == 'ingresos'
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: MyCarColors.border,
                                        width: 1.5,
                                      ),
                              ),
                            ),
                            child: const Text(
                              'Ingresos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _activeView = 'graficos';
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _activeView == 'graficos'
                                  ? MyCarColors.secondary
                                  : Colors.transparent,
                              foregroundColor: _activeView == 'graficos'
                                  ? Colors.white
                                  : MyCarColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: _activeView == 'graficos'
                                    ? BorderSide.none
                                    : BorderSide(
                                        color: MyCarColors.border,
                                        width: 1.5,
                                      ),
                              ),
                            ),
                            child: const Text(
                              'Gráficos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Contenido condicional según vista activa
                    _activeView == 'ingresos'
                        ? _buildIncomesTab()
                        : _buildChartsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSimpleInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MyCarColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: MyCarColors.textPrimary,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomesTab() {
    if (_isLoadingIncomes) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_incomes.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: MyCarColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay ingresos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MyCarColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Debes agregar ingresos para ver el historial',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: MyCarColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _incomes.length,
      itemBuilder: (context, index) {
        final income = _incomes[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MyCarColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MyCarColors.border, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      income.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MyCarColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(income.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MyCarColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${NumberFormat('#,##0.00').format(income.amount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MyCarColors.success,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<MapEntry<DateTime, double>> _groupIncomesByDay(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    List<Income> filteredIncomes;
    
    if (period == '7') {
      // Últimos 7 días: desde hace 6 días hasta hoy (inclusive) = 7 días totales
      final sevenDaysAgo = today.subtract(const Duration(days: 6));
      filteredIncomes = _incomes.where((income) {
        // Normalizar la fecha del ingreso para comparar solo día/mes/año
        final incomeDate = DateTime(
          income.date.year,
          income.date.month,
          income.date.day,
        );
        // Incluir desde sevenDaysAgo hasta today (inclusive)
        // Usar compareTo para comparación directa
        return incomeDate.compareTo(sevenDaysAgo) >= 0 && 
               incomeDate.compareTo(today) <= 0;
      }).toList();
      
      debugPrint('📊 Filtro 7 días:');
      debugPrint('   Hoy: $today');
      debugPrint('   Hace 7 días (desde): $sevenDaysAgo');
      debugPrint('   Total ingresos disponibles: ${_incomes.length}');
      debugPrint('   Ingresos filtrados: ${filteredIncomes.length}');
      if (_incomes.isNotEmpty) {
        final firstIncomeDate = DateTime(_incomes.first.date.year, _incomes.first.date.month, _incomes.first.date.day);
        final lastIncomeDate = DateTime(_incomes.last.date.year, _incomes.last.date.month, _incomes.last.date.day);
        debugPrint('   Primer ingreso (normalizado): $firstIncomeDate');
        debugPrint('   Último ingreso (normalizado): $lastIncomeDate');
        if (filteredIncomes.isNotEmpty) {
          final firstFilteredDate = DateTime(filteredIncomes.first.date.year, filteredIncomes.first.date.month, filteredIncomes.first.date.day);
          debugPrint('   Primer ingreso filtrado: $firstFilteredDate');
        }
      }
    } else if (period == '30') {
      // Últimos 30 días: desde hace 29 días hasta hoy (inclusive) = 30 días totales
      final thirtyDaysAgo = today.subtract(const Duration(days: 29));
      filteredIncomes = _incomes.where((income) {
        final incomeDate = DateTime(
          income.date.year,
          income.date.month,
          income.date.day,
        );
        // Incluir desde thirtyDaysAgo hasta today (inclusive)
        return incomeDate.compareTo(thirtyDaysAgo) >= 0 && 
               incomeDate.compareTo(today) <= 0;
      }).toList();
    } else {
      // 'all'
      filteredIncomes = _incomes;
    }
    
    // Agrupar por día y sumar montos
    final Map<DateTime, double> grouped = {};
    
    for (final income in filteredIncomes) {
      final day = DateTime(
        income.date.year,
        income.date.month,
        income.date.day,
      );
      grouped[day] = (grouped[day] ?? 0) + income.amount;
    }
    
    // Convertir a lista ordenada por fecha
    final entries = grouped.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    
    return entries;
  }

  Widget _buildChartsTab() {
    if (_isLoadingIncomes) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_incomes.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 64,
                  color: MyCarColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay ingresos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MyCarColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Debes agregar ingresos para ver los gráficos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MyCarColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final groupedData = _groupIncomesByDay(_selectedPeriod);
    
    // Calcular estadísticas (incluso si no hay datos, para mantener consistencia)
    final total = groupedData.fold<double>(0, (sum, entry) => sum + entry.value);
    final promedio = groupedData.isNotEmpty ? total / groupedData.length : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector de período (siempre visible)
          Row(
            children: [
              Expanded(
                child: _buildPeriodChip('7', '7 días'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPeriodChip('30', '30 días'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPeriodChip('all', 'Todos'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Mostrar estadísticas solo si hay datos
          if (groupedData.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    '\$${NumberFormat('#,##0.00').format(total)}',
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Promedio',
                    '\$${NumberFormat('#,##0.00').format(promedio)}',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Mostrar gráfico o mensaje de sin datos
          if (groupedData.isEmpty) ...[
            SizedBox(
              height: 300,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        size: 64,
                        color: MyCarColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay datos para este período',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: MyCarColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Intenta seleccionar "Todos" para ver todos los ingresos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MyCarColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Estadísticas (ya mostradas arriba si hay datos)
            // Gráfico con scroll horizontal
            SizedBox(
              height: 320,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: groupedData.length > 7 
                      ? (groupedData.length * 50.0) 
                      : double.infinity,
                  height: 300,
                  child: BarChart(
                    _buildBarChartData(groupedData),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MyCarColors.secondary.withValues(alpha: 0.1)
              : MyCarColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? MyCarColors.secondary
                : MyCarColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? MyCarColors.secondary
                  : MyCarColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyCarColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyCarColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MyCarColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MyCarColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: MyCarColors.success,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  BarChartData _buildBarChartData(List<MapEntry<DateTime, double>> groupedData) {
    if (groupedData.isEmpty) {
      return BarChartData(
        maxY: 100.0,
        barGroups: [],
      );
    }

    final maxY = groupedData.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.grey.shade800,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex >= 0 && groupIndex < groupedData.length) {
              final date = groupedData[groupIndex].key;
              final amount = groupedData[groupIndex].value;
              return BarTooltipItem(
                '${DateFormat('dd/MM').format(date)}\n\$${NumberFormat('#,##0.00').format(amount)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }
            return BarTooltipItem('', TextStyle());
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < groupedData.length) {
                final date = groupedData[value.toInt()].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('dd/MM').format(date),
                    style: TextStyle(
                      color: MyCarColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const Text('');
            },
            reservedSize: 50,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value >= 0) {
                return Text(
                  '\$${NumberFormat('#,##0').format(value)}',
                  style: TextStyle(
                    color: MyCarColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }
              return const Text('');
            },
            reservedSize: 50,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: MyCarColors.border, width: 1),
          left: BorderSide(color: MyCarColors.border, width: 1),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 5,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: MyCarColors.border.withValues(alpha: 0.3),
            strokeWidth: 1,
          );
        },
      ),
      barGroups: groupedData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: data.value,
              color: MyCarColors.success,
              width: 20,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
