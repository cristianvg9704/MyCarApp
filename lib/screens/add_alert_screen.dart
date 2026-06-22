import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/alert_provider.dart';
import '../providers/car_provider.dart';
import '../models/alert.dart';
import '../utils/my_car_colors.dart';
import '../config/supabase_config.dart';

class AddAlertScreen extends StatefulWidget {
  final String? initialCarId;
  final bool inModal;

  const AddAlertScreen({super.key, this.initialCarId, this.inModal = false});

  @override
  State<AddAlertScreen> createState() => _AddAlertScreenState();
}

class _AddAlertScreenState extends State<AddAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0); // Default 8:00 AM
  int? _notifyDaysBefore; // null, 1, o 3
  String? _selectedCarId;
  bool _isRecurring = false;
  String? _recurrenceType; // 'daily', 'weekly', 'monthly', 'custom_days'
  int? _recurrenceInterval; // Cada cuántos días/semanas/meses
  int? _recurrenceCount; // Cuántas veces se ejecutará la alerta
  bool _hasLoadedCars = false;

  @override
  void initState() {
    super.initState();
    // Normalizar la fecha inicial para que solo tenga fecha (sin hora)
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    if (widget.initialCarId != null) {
      _selectedCarId = widget.initialCarId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year, now.month, now.day);
    
    // Normalizar _selectedDate para comparar solo la fecha (sin hora)
    final DateTime selectedDateNormalized = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    
    // Asegurar que initialDate nunca sea anterior a firstDate
    // Si _selectedDate es anterior a hoy, usar firstDate como initialDate
    DateTime initialDate = selectedDateNormalized.compareTo(firstDate) < 0
        ? firstDate 
        : selectedDateNormalized;
    
    // Validación adicional: asegurar que initialDate >= firstDate (siempre se ejecuta)
    if (initialDate.compareTo(firstDate) < 0) {
      debugPrint('ADVERTENCIA: initialDate ($initialDate) es anterior a firstDate ($firstDate). Corrigiendo...');
      initialDate = firstDate;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    
    if (picked != null) {
      // Normalizar la fecha seleccionada para guardar solo la fecha (sin hora)
      final DateTime pickedNormalized = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );
      setState(() {
        _selectedDate = pickedNormalized;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: MyCarColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }


  Future<void> _saveAlert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCarId == null || _selectedCarId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un vehículo')),
      );
      return;
    }

    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null || currentUser.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Usuario no autenticado')),
        );
      }
      return;
    }

    // Convertir TimeOfDay a String formato "HH:mm"
    final hourStr = _selectedTime.hour.toString().padLeft(2, '0');
    final minuteStr = _selectedTime.minute.toString().padLeft(2, '0');
    final notificationTimeStr = '$hourStr:$minuteStr';

    // Crear alerta personalizada
    final alert = Alert(
      userId: currentUser.id,
      carId: _selectedCarId!,
      title: _titleController.text.trim(),
      alertDate: _selectedDate,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isRecurring: _isRecurring,
      recurrenceType: _recurrenceType,
      recurrenceValue: _recurrenceInterval,
      recurrenceCount: _recurrenceCount,
      templateType: 'custom',
      notificationTime: notificationTimeStr,
      notifyDaysBefore: _notifyDaysBefore,
    );

    try {
      await Provider.of<AlertProvider>(context, listen: false).addAlert(alert);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerta creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (widget.inModal) {
          Navigator.of(context).pop(true);
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear alerta: $e')),
        );
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(10),
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
                            ],
                          );
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedCarId,
                          decoration: InputDecoration(
                            labelText: 'Vehículo *',
                            filled: true,
                            fillColor: MyCarColors.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
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
                    
                    // Título
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Título *',
                        filled: true,
                        fillColor: MyCarColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa un título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descripción (opcional)',
                        filled: true,
                        fillColor: MyCarColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
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
                    ),
                    const SizedBox(height: 16),

                    // Selector de fecha
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
                                    DateFormat('dd/MM/yyyy').format(_selectedDate),
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

                    // Selector de hora
                    InkWell(
                      onTap: () => _selectTime(context),
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
                              Icons.access_time_outlined,
                              color: MyCarColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hora de notificación',
                                    style: TextStyle(
                                      color: MyCarColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedTime.format(context),
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

                    // Selector de días antes
                    DropdownButtonFormField<int?>(
                      value: _notifyDaysBefore,
                      decoration: InputDecoration(
                        labelText: 'Notificar días antes',
                        hintText: 'No notificar antes',
                        filled: true,
                        fillColor: MyCarColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
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
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No notificar antes'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 1,
                          child: Text('1 día antes'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 3,
                          child: Text('3 días antes'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _notifyDaysBefore = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Toggle de recurrencia
                    SwitchListTile(
                      title: const Text('Alerta recurrente'),
                      subtitle: const Text('La alerta se repetirá automáticamente'),
                      value: _isRecurring,
                      onChanged: (value) {
                        setState(() {
                          _isRecurring = value;
                          if (!value) {
                            _recurrenceType = null;
                            _recurrenceInterval = null;
                            _recurrenceCount = null;
                          }
                        });
                      },
                      activeColor: MyCarColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Configuración de recurrencia
                    if (_isRecurring) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _recurrenceType,
                        decoration: InputDecoration(
                          labelText: 'Tipo de recurrencia',
                          filled: true,
                          fillColor: MyCarColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('Diario')),
                          DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                          DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                          DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                          DropdownMenuItem(value: 'custom_days', child: Text('Personalizada (días)')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _recurrenceType = value;
                            if (value != 'custom_days' && value != 'monthly' && value != 'weekly') {
                              _recurrenceInterval = null;
                            }
                          });
                        },
                      ),
                      // Campo para intervalo (cada cuántos días/semanas/meses)
                      if (_recurrenceType != null && 
                          (_recurrenceType == 'custom_days' || 
                           _recurrenceType == 'monthly' || 
                           _recurrenceType == 'weekly')) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _recurrenceType == 'custom_days'
                                ? 'Cada cuántos días'
                                : _recurrenceType == 'weekly'
                                    ? 'Cada cuántas semanas'
                                    : 'Cada cuántos meses',
                            filled: true,
                            fillColor: MyCarColors.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _recurrenceInterval = int.tryParse(value);
                            });
                          },
                        ),
                      ],
                      // Campo para frecuencia (cuántas veces se ejecutará)
                      const SizedBox(height: 16),
                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '¿Cuántas veces se ejecutará?',
                          hintText: 'Ej: 5 (se ejecutará 5 veces)',
                          filled: true,
                          fillColor: MyCarColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _recurrenceCount = int.tryParse(value);
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveAlert,
                        icon: const Icon(Icons.check_circle_outline, size: 22),
                        label: const Text(
                          'Guardar Alerta',
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
                          shadowColor: MyCarColors.primary.withValues(alpha: 0.3),
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
          'Nueva Alerta',
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
