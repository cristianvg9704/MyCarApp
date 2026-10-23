import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/car_transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/my_car_colors.dart';

IconData transactionIcon(CarTransaction t) {
  if (t.isIncome) return Icons.arrow_downward_rounded;
  switch (t.category) {
    case TransactionCategory.fuel:
      return Icons.local_gas_station_outlined;
    case TransactionCategory.maintenance:
      return Icons.build_outlined;
    case TransactionCategory.other:
    case null:
      return Icons.arrow_upward_rounded;
  }
}

/// Fila de un movimiento: icono por tipo/categoría, descripción, fecha y
/// monto con signo (verde para ingresos, rojo para egresos).
class TransactionTile extends StatelessWidget {
  final CarTransaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? MyCarColors.success : MyCarColors.error;
    final subtitle = [
      DateFormat('dd/MM/yyyy').format(transaction.date),
      if (transaction.isExpense && transaction.category != null)
        transaction.category!.label,
    ].join(' · ');

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(transactionIcon(transaction), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MyCarColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MyCarColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatSigned(transaction.signedAmount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
