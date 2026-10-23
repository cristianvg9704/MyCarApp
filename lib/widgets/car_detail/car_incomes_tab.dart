import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/income.dart';
import '../../utils/my_car_colors.dart';
import '../empty_state.dart';

/// Tab "Ingresos": historial de ingresos del vehículo.
class CarIncomesTab extends StatelessWidget {
  final List<Income> incomes;
  final bool isLoading;

  const CarIncomesTab({
    super.key,
    required this.incomes,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (incomes.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No hay ingresos',
        message: 'Debes agregar ingresos para ver el historial',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 40,
      ),
      itemCount: incomes.length,
      itemBuilder: (context, index) => _IncomeTile(income: incomes[index]),
    );
  }
}

class _IncomeTile extends StatelessWidget {
  final Income income;

  const _IncomeTile({required this.income});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
  }
}
