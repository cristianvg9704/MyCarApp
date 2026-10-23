import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/car.dart';
import '../models/income.dart';
import '../services/database_helper.dart';
import '../providers/car_provider.dart';
import '../utils/my_car_colors.dart';
import '../utils/vehicle_modal_helper.dart';
import '../widgets/car_detail/car_charts_tab.dart';
import '../widgets/car_detail/car_incomes_tab.dart';
import '../widgets/car_detail/car_info_tab.dart';
import '../widgets/car_mileage_tab.dart';

typedef CarLoader = Future<Car?> Function(String carId);
typedef IncomesLoader = Future<List<Income>> Function(String carId);

class CarDetailScreen extends StatefulWidget {
  final String carId;

  /// Cargadores inyectables para poder probar la pantalla sin Supabase.
  final CarLoader? carLoader;
  final IncomesLoader? incomesLoader;

  const CarDetailScreen({
    super.key,
    required this.carId,
    this.carLoader,
    this.incomesLoader,
  });

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  Car? _car;
  bool _isLoading = true;
  List<Income> _incomes = [];
  bool _isLoadingIncomes = false;

  CarLoader get _loadCarData =>
      widget.carLoader ?? DatabaseHelper.instance.getCar;
  IncomesLoader get _loadIncomesData =>
      widget.incomesLoader ?? DatabaseHelper.instance.getIncomesByCar;

  @override
  void initState() {
    super.initState();
    _loadCar();
  }

  Future<void> _loadCar() async {
    try {
      final car = await _loadCarData(widget.carId);
      if (!mounted) return;
      setState(() {
        _car = car;
        _isLoading = false;
      });
      if (car != null) _loadIncomes();
    } catch (e) {
      debugPrint('Error loading car: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadIncomes() async {
    final carId = _car?.id;
    if (carId == null) return;
    setState(() => _isLoadingIncomes = true);
    try {
      final incomes = await _loadIncomesData(carId);
      if (!mounted) return;
      setState(() {
        _incomes = incomes;
        _isLoadingIncomes = false;
      });
    } catch (e) {
      debugPrint('Error loading incomes: $e');
      if (mounted) setState(() => _isLoadingIncomes = false);
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

    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<CarProvider>(
        context,
        listen: false,
      ).deleteCar(_car!.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehículo eliminado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editCar() async {
    if (_car == null) return;
    final success = await VehicleModalHelper.showEditVehicleModal(
      context,
      _car!,
    );
    if (success == true && mounted) _loadCar();
  }

  Widget _backButton() => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    },
  );

  Widget _title(String text) => Text(
    text,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: MyCarColors.backgroundLight,
        appBar: AppBar(
          leading: _backButton(),
          title: _title('Detalle del Vehículo'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final car = _car;
    if (car == null) return _buildNotFound(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: MyCarColors.backgroundLight,
        appBar: AppBar(
          leading: _backButton(),
          title: _title('${car.brand} ${car.model}'),
          actions: [_buildMenu()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Detalle'),
              Tab(text: 'Ingresos'),
              Tab(text: 'Gráficos'),
              Tab(text: 'Kilometraje'),
            ],
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: TabBarView(
            children: [
              CarInfoTab(car: car),
              CarIncomesTab(incomes: _incomes, isLoading: _isLoadingIncomes),
              CarChartsTab(incomes: _incomes, isLoading: _isLoadingIncomes),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).padding.bottom + 40,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CarMileageTab(
                    carId: widget.carId,
                    purchaseDate: car.purchaseDate,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: MyCarColors.backgroundLight,
      appBar: AppBar(
        leading: _backButton(),
        title: _title('Detalle del Vehículo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 72,
              color: MyCarColors.error,
            ),
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

  Widget _buildMenu() {
    return Padding(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withValues(alpha: 0.95),
        elevation: 8,
        onSelected: (value) {
          if (value == 'edit') {
            _editCar();
          } else if (value == 'delete') {
            _deleteCar();
          }
        },
        itemBuilder: (_) => [
          _menuItem(
            value: 'edit',
            label: 'Editar',
            icon: Icons.edit_outlined,
            color: MyCarColors.primary,
            background: MyCarColors.primaryLight,
            textColor: MyCarColors.textPrimary,
          ),
          _menuItem(
            value: 'delete',
            label: 'Eliminar',
            icon: Icons.delete_outline,
            color: MyCarColors.error,
            background: MyCarColors.error.withValues(alpha: 0.1),
            textColor: MyCarColors.error,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
    required Color textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
