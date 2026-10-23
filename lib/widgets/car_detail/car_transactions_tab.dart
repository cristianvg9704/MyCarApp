import 'package:flutter/material.dart';
import '../../models/car_transaction.dart';
import '../empty_state.dart';
import '../transaction_tile.dart';

/// Tab "Movimientos": historial de ingresos y egresos del vehículo.
class CarTransactionsTab extends StatefulWidget {
  final List<CarTransaction> transactions;
  final bool isLoading;

  const CarTransactionsTab({
    super.key,
    required this.transactions,
    required this.isLoading,
  });

  @override
  State<CarTransactionsTab> createState() => _CarTransactionsTabState();
}

class _CarTransactionsTabState extends State<CarTransactionsTab> {
  TransactionType? _filter; // null = todos

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.transactions.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No hay movimientos',
        message: 'Registra ingresos y egresos para ver el historial',
      );
    }

    final visible = _filter == null
        ? widget.transactions
        : widget.transactions.where((t) => t.type == _filter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final type in TransactionType.values)
                ChoiceChip(
                  label: Text(
                    type == TransactionType.income ? 'Ingresos' : 'Egresos',
                  ),
                  selected: _filter == type,
                  onSelected: (_) => setState(() => _filter = type),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: _filter == TransactionType.income
                      ? 'No hay ingresos'
                      : 'No hay egresos',
                  message: 'No hay movimientos de este tipo',
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).padding.bottom + 40,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, index) =>
                      TransactionTile(transaction: visible[index]),
                ),
        ),
      ],
    );
  }
}
