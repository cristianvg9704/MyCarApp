import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/income_provider.dart';
import '../providers/car_provider.dart';
import '../models/car.dart';
import '../utils/my_car_colors.dart';
import '../utils/income_modal_helper.dart';

class CarIncomesScreen extends StatelessWidget {
  final String carId;

  const CarIncomesScreen({super.key, required this.carId});

  @override
  Widget build(BuildContext context) {
    final incomeProvider = Provider.of<IncomeProvider>(context, listen: false);

    // Cargar los ingresos del vehículo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      incomeProvider.loadIncomesByCar(carId);
    });

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
        title: Consumer<CarProvider>(
          builder: (context, carProvider, child) {
            final car = carProvider.cars.firstWhere(
              (car) => car.id == carId,
              orElse: () => Car(
                id: carId,
                userId: '', // Valor temporal, no se usará si el carro existe
                brand: 'Vehículo',
                model: '',
                year: DateTime.now().year,
              ),
            );
            return Text(
              '${car.brand} ${car.model}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            );
          },
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
              onPressed: () => IncomeModalHelper.showAddIncomeModal(context, carId: carId),
              tooltip: 'Agregar ingreso',
            ),
          ),
        ],
      ),
      body: Consumer<IncomeProvider>(
        builder: (context, incomeProvider, child) {
          if (incomeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (incomeProvider.incomes.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: MyCarColors.primaryLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.attach_money_outlined,
                      size: 72,
                      color: MyCarColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'No hay ingresos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MyCarColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Agrega tu primer ingreso\npara este vehículo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MyCarColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => IncomeModalHelper.showAddIncomeModal(context, carId: carId),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Agregar Ingreso',
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

          // Calcular total
          final total = incomeProvider.incomes
              .map((income) => income.amount)
              .fold(0.0, (sum, amount) => sum + amount);

          return Column(
            children: [
              // Resumen de ingresos
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: MyCarColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: MyCarColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total de Ingresos',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(
                            symbol: '\$',
                            decimalDigits: 2,
                          ).format(total),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${incomeProvider.incomes.length}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de ingresos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: incomeProvider.incomes.length,
                  itemBuilder: (context, index) {
                    final income = incomeProvider.incomes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: MyCarColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.attach_money_rounded,
                            color: MyCarColors.primary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          income.description,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: MyCarColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(income.date),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: MyCarColors.textSecondary,
                                  fontSize: 13,
                                ),
                          ),
                        ),
                        trailing: Text(
                          NumberFormat.currency(
                            symbol: '\$',
                            decimalDigits: 0,
                          ).format(income.amount),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: MyCarColors.primary,
                              ),
                        ),
                        onTap: () {
                          // Aquí puedes agregar funcionalidad para editar el ingreso
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
