import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/transaction_provider.dart';
import '../providers/car_provider.dart';
import '../models/car.dart';
import '../utils/currency_formatter.dart';
import '../utils/my_car_colors.dart';
import '../utils/transaction_chart_utils.dart';
import '../utils/transaction_modal_helper.dart';
import '../widgets/transaction_tile.dart';

class CarFinancesScreen extends StatelessWidget {
  final String carId;

  const CarFinancesScreen({super.key, required this.carId});

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(
      context,
      listen: false,
    );

    // Cargar los movimientos del vehículo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      transactionProvider.loadByCar(carId);
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
              onPressed: () => TransactionModalHelper.showAddTransactionModal(
                context,
                carId: carId,
              ),
              tooltip: 'Registrar movimiento',
            ),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
          if (transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (transactionProvider.transactions.isEmpty) {
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
                    'No hay movimientos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MyCarColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Registra tu primer ingreso o egreso\npara este vehículo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MyCarColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => TransactionModalHelper.showAddTransactionModal(
                      context,
                      carId: carId,
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Registrar Movimiento',
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

          final transactions = transactionProvider.transactions;
          final summary = TransactionSummary.of(transactions);

          return Column(
            children: [
              // Resumen: balance, ingresos y egresos
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(summary.balance),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ingresos ${CurrencyFormatter.format(summary.income)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Egresos ${CurrencyFormatter.format(summary.expense)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Lista de movimientos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) =>
                      TransactionTile(transaction: transactions[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
