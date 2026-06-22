import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/income_provider.dart';
import '../providers/car_provider.dart';
import '../models/income.dart';
import '../utils/my_car_colors.dart';
import '../utils/vehicle_modal_helper.dart';
import '../config/supabase_config.dart';

class AddIncomeScreen extends StatefulWidget {
  final String? initialCarId;
  final bool inModal;

  const AddIncomeScreen({super.key, this.initialCarId, this.inModal = false});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCarId;
  bool _hasLoadedCars = false;

  @override
  void initState() {
    super.initState();
    // Establecer carId inicial si se proporciona
    if (widget.initialCarId != null) {
      _selectedCarId = widget.initialCarId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si no hay carId inicial y NO estamos en un modal, intentar obtenerlo de los query parameters
    if (_selectedCarId == null && !widget.inModal) {
      try {
        final uri = GoRouterState.of(context).uri;
        final carIdStr = uri.queryParameters['carId'];
        if (carIdStr != null && carIdStr.isNotEmpty) {
          _selectedCarId = carIdStr;
        }
      } catch (e) {
        // Si no hay GoRouterState disponible (por ejemplo, en un modal), ignorar el error
        debugPrint('No se pudo obtener carId de query parameters: $e');
      }
    }
    // Cargar vehículos al iniciar (solo una vez)
    if (!_hasLoadedCars && mounted) {
      _hasLoadedCars = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final carProvider = Provider.of<CarProvider>(context, listen: false);
          if (carProvider.cars.isEmpty) {
            carProvider.loadCars();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveIncome() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCarId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona un vehículo')),
        );
        return;
      }

      // Obtener userId del usuario autenticado
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null || currentUser.id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Usuario no autenticado')),
          );
        }
        return;
      }

      final income = Income(
        userId: currentUser.id,
        carId: _selectedCarId!,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        date: _selectedDate,
        category: null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      try {
        await Provider.of<IncomeProvider>(
          context,
          listen: false,
        ).addIncome(income);
        if (mounted) {
          // Esperar un frame antes de cerrar el modal para evitar conflictos con el árbol de widgets
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true); // Retornar true para indicar éxito
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contenedor con formulario
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de vehículo
                    Consumer<CarProvider>(
                      builder: (context, carProvider, child) {
                        if (carProvider.isLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (carProvider.cars.isEmpty) {
                          return Column(
                            children: [
                              Text(
                                'No hay vehículos registrados',
                                style: TextStyle(
                                  color: MyCarColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () =>
                                    VehicleModalHelper.showAddVehicleModal(
                                      context,
                                    ),
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
                          value: _selectedCarId,
                          decoration: InputDecoration(
                            labelText: 'Vehículo *',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            labelStyle: TextStyle(
                              color: MyCarColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: MyCarColors.border,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: MyCarColors.border,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: MyCarColors.primary,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: MyCarColors.error,
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: MyCarColors.error,
                                width: 2,
                              ),
                            ),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          style: TextStyle(
                            color: MyCarColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          items: carProvider.cars.map((car) {
                            return DropdownMenuItem<String>(
                              value: car.id,
                              child: Text(
                                '${car.brand} ${car.model} (${car.year})',
                                style: TextStyle(
                                  color: MyCarColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCarId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor selecciona un vehículo';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción *',
                        hintText: 'Ej: Servicio de taxi',
                        filled: true,
                        fillColor: MyCarColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: MyCarColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: TextStyle(
                          color: MyCarColors.textTertiary,
                          fontSize: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.error,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.error,
                            width: 2,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: MyCarColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa una descripción';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Monto *',
                        hintText: 'Ej: 50000',
                        filled: true,
                        fillColor: MyCarColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: MyCarColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: TextStyle(
                          color: MyCarColors.textTertiary,
                          fontSize: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.error,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.error,
                            width: 2,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: MyCarColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa el monto';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount <= 0) {
                          return 'Ingresa un monto válido mayor a cero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: MyCarColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: MyCarColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fecha *',
                                    style: TextStyle(
                                      color: MyCarColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate),
                                    style: TextStyle(
                                      color: MyCarColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: MyCarColors.textTertiary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notas',
                        hintText: 'Información adicional...',
                        filled: true,
                        fillColor: MyCarColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: MyCarColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: TextStyle(
                          color: MyCarColors.textTertiary,
                          fontSize: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: MyCarColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: MyCarColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveIncome,
                        icon: const Icon(Icons.check_circle_outline, size: 22),
                        label: const Text(
                          'Guardar Ingreso',
                          style: TextStyle(
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
                          shadowColor: MyCarColors.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formContent = _buildForm(context);

    if (widget.inModal) {
      return formContent;
    }

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
          'Agregar Ingreso',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: formContent,
    );
  }
}
