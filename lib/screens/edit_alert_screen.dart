import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/alert_provider.dart';
import '../providers/car_provider.dart';
import '../models/alert.dart';
import '../utils/my_car_colors.dart';
import '../services/alert_templates.dart';
import '../config/supabase_config.dart';

class EditAlertScreen extends StatefulWidget {
  final Alert alert;
  final bool inModal;

  const EditAlertScreen({super.key, required this.alert, this.inModal = false});

  @override
  State<EditAlertScreen> createState() => _EditAlertScreenState();
}

class _EditAlertScreenState extends State<EditAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _recurrenceValueController;
  late DateTime _selectedDate;
  late String _selectedCarId;
  String? _selectedTemplateId;
  late bool _isRecurring;
  String? _recurrenceType;
  int? _recurrenceValue;
  bool _hasLoadedCars = false;

  @override
  void initState() {
    super.initState();
    // Cargar datos de la alerta existente
    _titleController = TextEditingController(text: widget.alert.title);
    _descriptionController = TextEditingController(text: widget.alert.description ?? '');
    _recurrenceValueController = TextEditingController(
      text: widget.alert.recurrenceValue?.toString() ?? '',
    );
    _selectedDate = widget.alert.alertDate;
    _selectedCarId = widget.alert.carId;
    _selectedTemplateId = widget.alert.templateType;
    _isRecurring = widget.alert.isRecurring;
    _recurrenceType = widget.alert.recurrenceType;
    _recurrenceValue = widget.alert.recurrenceValue;
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
    _recurrenceValueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _applyTemplate(String templateId) {
    setState(() {
      _selectedTemplateId = templateId;
      
      switch (templateId) {
        case 'soat':
          _titleController.text = 'Renovación SOAT';
          _isRecurring = true;
          _recurrenceType = 'yearly';
          _recurrenceValue = null;
          _recurrenceValueController.text = '';
          break;
        case 'maintenance':
          _titleController.text = 'Mantenimiento General';
          _isRecurring = true;
          _recurrenceType = 'monthly';
          _recurrenceValue = 3;
          _recurrenceValueController.text = '3';
          break;
        case 'technical_review':
          _titleController.text = 'Revisión Técnica';
          _isRecurring = true;
          _recurrenceType = 'yearly';
          _recurrenceValue = null;
          _recurrenceValueController.text = '';
          break;
        case 'insurance':
          _titleController.text = 'Renovación Seguro';
          _isRecurring = true;
          _recurrenceType = 'yearly';
          _recurrenceValue = null;
          _recurrenceValueController.text = '';
          break;
        case 'oil_change':
          _titleController.text = 'Cambio de Aceite';
          _isRecurring = true;
          _recurrenceType = 'monthly';
          _recurrenceValue = 3;
          _recurrenceValueController.text = '3';
          break;
        case 'tire_change':
          _titleController.text = 'Revisión/Cambio de Neumáticos';
          _isRecurring = true;
          _recurrenceType = 'yearly';
          _recurrenceValue = 2;
          _recurrenceValueController.text = '2';
          break;
        case 'custom':
        default:
          // No cambiar los valores existentes si es custom
          break;
      }
    });
  }

  Future<void> _updateAlert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCarId.isEmpty) {
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

    // Crear alerta actualizada usando copyWith para preservar el ID y otros campos
    final updatedAlert = widget.alert.copyWith(
      carId: _selectedCarId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      alertDate: _selectedDate,
      isRecurring: _isRecurring,
      recurrenceType: _recurrenceType,
      recurrenceValue: _recurrenceValue,
      templateType: _selectedTemplateId,
    );

    try {
      await Provider.of<AlertProvider>(context, listen: false).updateAlert(updatedAlert);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerta actualizada exitosamente'),
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
          SnackBar(content: Text('Error al actualizar alerta: $e')),
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
                    // Selector de plantilla
                    Text(
                      'Plantilla (opcional)',
                      style: TextStyle(
                        color: MyCarColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedTemplateId,
                      decoration: InputDecoration(
                        labelText: 'Seleccionar plantilla',
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
                      items: AlertTemplates.getAvailableTemplates().map((template) {
                        return DropdownMenuItem<String>(
                          value: template.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                template.name,
                                style: TextStyle(
                                  color: MyCarColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                template.description,
                                style: TextStyle(
                                  color: MyCarColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _applyTemplate(value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
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
                              _selectedCarId = value!;
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
                            _recurrenceValue = null;
                            _recurrenceValueController.text = '';
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
                            if (value != 'custom_days' && value != 'monthly') {
                              _recurrenceValue = null;
                              _recurrenceValueController.text = '';
                            }
                          });
                        },
                      ),
                      if (_recurrenceType == 'custom_days' || _recurrenceType == 'monthly') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _recurrenceValueController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _recurrenceType == 'custom_days'
                                ? 'Cada cuántos días'
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
                              _recurrenceValue = int.tryParse(value);
                            });
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),

                    // Botón actualizar
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _updateAlert,
                        icon: const Icon(Icons.check_circle_outline, size: 22),
                        label: const Text(
                          'Actualizar Alerta',
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
          'Editar Alerta',
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
