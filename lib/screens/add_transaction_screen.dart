import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../config/supabase_config.dart';
import '../models/car_transaction.dart';
import '../providers/car_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/form_decoration.dart';
import '../utils/my_car_colors.dart';
import '../utils/vehicle_modal_helper.dart';

/// Formulario para registrar un ingreso o un egreso de un vehículo.
class AddTransactionScreen extends StatefulWidget {
  final String? initialCarId;
  final TransactionType initialType;
  final bool inModal;

  /// Devuelve el id del usuario autenticado. Inyectable para tests.
  final String? Function()? currentUserId;

  const AddTransactionScreen({
    super.key,
    this.initialCarId,
    this.initialType = TransactionType.income,
    this.inModal = false,
    this.currentUserId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _litersController = TextEditingController();
  final _odometerController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCarId;
  late TransactionType _type = widget.initialType;
  TransactionCategory _category = TransactionCategory.fuel;
  bool _hasLoadedCars = false;
  bool _isSaving = false;

  bool get _isExpense => _type == TransactionType.expense;
  bool get _isFuel => _isExpense && _category == TransactionCategory.fuel;
  bool get _isMaintenance =>
      _isExpense && _category == TransactionCategory.maintenance;

  String? _currentUserId() => widget.currentUserId != null
      ? widget.currentUserId!()
      : SupabaseConfig.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _selectedCarId = widget.initialCarId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin carId inicial y fuera de un modal, tomarlo de los query parameters
    if (_selectedCarId == null && !widget.inModal) {
      try {
        final carId = GoRouterState.of(context).uri.queryParameters['carId'];
        if (carId != null && carId.isNotEmpty) _selectedCarId = carId;
      } catch (e) {
        debugPrint('No se pudo obtener carId de query parameters: $e');
      }
    }
    if (!_hasLoadedCars) {
      _hasLoadedCars = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final carProvider = Provider.of<CarProvider>(context, listen: false);
        if (carProvider.cars.isEmpty) carProvider.loadCars();
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _litersController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final carId = _selectedCarId;
    if (carId == null) {
      _showMessage('Por favor selecciona un vehículo');
      return;
    }

    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      _showMessage('Error: Usuario no autenticado');
      return;
    }

    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();
    final transaction = CarTransaction(
      userId: userId,
      carId: carId,
      type: _type,
      description: description.isEmpty ? _category.label : description,
      amount: parseAmount(_amountController.text)!,
      date: _selectedDate,
      category: _isExpense ? _category : null,
      notes: notes.isEmpty ? null : notes,
      liters: _isFuel ? parseAmount(_litersController.text) : null,
      odometerKm: _isFuel || _isMaintenance
          ? parseAmount(_odometerController.text)
          : null,
    );

    setState(() => _isSaving = true);
    try {
      await Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).add(transaction);
      if (!mounted) return;
      // Esperar un frame antes de cerrar el modal para evitar conflictos con el árbol de widgets
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _requiredNumber(String? value, String emptyMessage) {
    if (value == null || value.trim().isEmpty) return emptyMessage;
    final number = parseAmount(value);
    if (number == null || number <= 0) {
      return 'Ingresa un valor válido mayor a cero';
    }
    return null;
  }

  String? _optionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = parseAmount(value);
    if (number == null || number <= 0) {
      return 'Ingresa un valor válido mayor a cero';
    }
    return null;
  }

  Widget _buildCarSelector() {
    return Consumer<CarProvider>(
      builder: (context, carProvider, _) {
        if (carProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (carProvider.cars.isEmpty) {
          return Column(
            children: [
              const Text(
                'No hay vehículos registrados',
                style: TextStyle(color: MyCarColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => VehicleModalHelper.showAddVehicleModal(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Agregar Vehículo'),
                style: FilledButton.styleFrom(
                  backgroundColor: MyCarColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedCarId,
          decoration: myCarInputDecoration(
            label: 'Vehículo *',
            radius: 20,
            fillColor: Colors.white,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(20),
          style: myCarInputTextStyle,
          items: [
            for (final car in carProvider.cars)
              DropdownMenuItem<String>(
                value: car.id,
                child: Text('${car.brand} ${car.model} (${car.year})'),
              ),
          ],
          onChanged: (value) => setState(() => _selectedCarId = value),
          validator: (value) =>
              value == null ? 'Por favor selecciona un vehículo' : null,
        );
      },
    );
  }

  Widget _buildTypeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TransactionType>(
        segments: const [
          ButtonSegment(
            value: TransactionType.income,
            label: Text('Ingreso'),
            icon: Icon(Icons.arrow_downward_rounded),
          ),
          ButtonSegment(
            value: TransactionType.expense,
            label: Text('Egreso'),
            icon: Icon(Icons.arrow_upward_rounded),
          ),
        ],
        selected: {_type},
        onSelectionChanged: (selection) =>
            setState(() => _type = selection.first),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      children: [
        for (final category in TransactionCategory.values)
          ChoiceChip(
            label: Text(category.label),
            selected: _category == category,
            onSelected: (_) => setState(() => _category = category),
          ),
      ],
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: MyCarColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MyCarColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: MyCarColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fecha *',
                    style: TextStyle(
                      color: MyCarColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: myCarInputTextStyle,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: MyCarColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    const gap = SizedBox(height: 16);
    const decimalKeyboard = TextInputType.numberWithOptions(decimal: true);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeSelector(),
                gap,
                _buildCarSelector(),
                if (_isExpense) ...[gap, _buildCategorySelector()],
                gap,
                TextFormField(
                  controller: _descriptionController,
                  decoration: myCarInputDecoration(
                    label: _isExpense ? 'Descripción' : 'Descripción *',
                    hint: _isExpense ? 'Ej: Tanqueo' : 'Ej: Servicio de taxi',
                  ),
                  style: myCarInputTextStyle,
                  validator: (value) => !_isExpense &&
                          (value == null || value.trim().isEmpty)
                      ? 'Por favor ingresa una descripción'
                      : null,
                ),
                gap,
                TextFormField(
                  controller: _amountController,
                  decoration: myCarInputDecoration(
                    label: 'Monto *',
                    hint: 'Ej: 50000',
                  ),
                  style: myCarInputTextStyle,
                  keyboardType: decimalKeyboard,
                  validator: (value) =>
                      _requiredNumber(value, 'Por favor ingresa el monto'),
                ),
                if (_isFuel) ...[
                  gap,
                  TextFormField(
                    controller: _litersController,
                    decoration: myCarInputDecoration(
                      label: 'Litros',
                      hint: 'Ej: 10.5',
                    ),
                    style: myCarInputTextStyle,
                    keyboardType: decimalKeyboard,
                    validator: _optionalNumber,
                  ),
                ],
                if (_isFuel || _isMaintenance) ...[
                  gap,
                  TextFormField(
                    controller: _odometerController,
                    decoration: myCarInputDecoration(
                      label: 'Kilometraje',
                      hint: 'Ej: 45200',
                    ),
                    style: myCarInputTextStyle,
                    keyboardType: decimalKeyboard,
                    validator: _optionalNumber,
                  ),
                ],
                gap,
                _buildDateField(),
                gap,
                TextFormField(
                  controller: _notesController,
                  decoration: myCarInputDecoration(
                    label: 'Notas',
                    hint: 'Información adicional...',
                  ),
                  style: myCarInputTextStyle,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: Text(
                      'Guardar ${_type.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MyCarColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                      shadowColor: MyCarColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inModal) return _buildForm();

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
          'Registrar Movimiento',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _buildForm(),
    );
  }
}
