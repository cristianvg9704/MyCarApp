import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/car_provider.dart';
import '../services/transaction_repository.dart';
import '../utils/currency_formatter.dart';
import '../utils/my_car_colors.dart';
import '../utils/transaction_chart_utils.dart';
import '../utils/transaction_modal_helper.dart';
import '../utils/vehicle_image_helper.dart';
import '../utils/vehicle_modal_helper.dart';

class FinancesListScreen extends StatelessWidget {
  final TransactionRepository? repository;

  const FinancesListScreen({super.key, this.repository});

  Widget _buildCarThumbnail(String? imageBase64) {
    const fallback = Icon(
      Icons.directions_car,
      color: Colors.white,
      size: 28,
    );
    final bytes = VehicleImage.decode(imageBase64);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return fallback;
  }

  Future<TransactionSummary> _getSummaryForCar(String? carId) async {
    const empty = TransactionSummary(
      income: 0,
      expense: 0,
      expenseByCategory: {},
    );
    if (carId == null || carId.isEmpty) return empty;
    try {
      final repo = repository ?? SupabaseTransactionRepository();
      return TransactionSummary.of(await repo.getByCar(carId));
    } catch (e) {
      debugPrint('Error getting car summary: $e');
      return empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyCarColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Finanzas',
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
              onPressed: () =>
                  TransactionModalHelper.showAddTransactionModal(context),
              tooltip: 'Registrar movimiento',
            ),
          ),
        ],
      ),
      body: Consumer<CarProvider>(
        builder: (context, carProvider, child) {
          // Cargar vehículos si no están cargados. No reintentar automáticamente
          // tras un error: eso causaría un loop de reintentos en cada rebuild;
          // el usuario reintenta explícitamente con el botón "Reintentar".
          if (!carProvider.isLoading &&
              carProvider.cars.isEmpty &&
              carProvider.errorMessage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              carProvider.loadCars();
            });
          }

          if (carProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (carProvider.errorMessage != null && carProvider.cars.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 72,
                    color: MyCarColors.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    carProvider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MyCarColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => carProvider.loadCars(),
                    style: FilledButton.styleFrom(
                      backgroundColor: MyCarColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (carProvider.cars.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    'Agrega un vehículo para comenzar\na registrar ingresos y egresos',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MyCarColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => VehicleModalHelper.showAddVehicleModal(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Agregar Vehículo',
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
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: carProvider.cars.length,
            itemBuilder: (context, index) {
              final car = carProvider.cars[index];
              return FutureBuilder<TransactionSummary>(
                future: _getSummaryForCar(car.id),
                builder: (context, snapshot) {
                  final summary = snapshot.data;
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
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (car.id != null) {
                            TransactionModalHelper.showAddTransactionModal(
                              context,
                              carId: car.id!,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: MyCarColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MyCarColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildCarThumbnail(car.imageBase64),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${car.brand} ${car.model}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: MyCarColors.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 14,
                                              color: MyCarColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Año ${car.year}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: MyCarColors
                                                        .textSecondary,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        if (car.plateNumber != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .confirmation_number_outlined,
                                                size: 14,
                                                color:
                                                    MyCarColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                car.plateNumber!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: MyCarColors
                                                          .textSecondary,
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 18,
                                          color: MyCarColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          CurrencyFormatter.format(
                                            summary?.balance ?? 0,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color:
                                                    (summary?.balance ?? 0) >= 0
                                                    ? MyCarColors.primary
                                                    : MyCarColors.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ingresos ${CurrencyFormatter.format(summary?.income ?? 0)}'
                                      ' · Egresos ${CurrencyFormatter.format(summary?.expense ?? 0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: MyCarColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.history_rounded,
                                  color: MyCarColors.textTertiary,
                                ),
                                onPressed: () {
                                  if (car.id != null) {
                                    context.go('/car-incomes?carId=${car.id}');
                                  }
                                },
                                tooltip: 'Ver historial',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
