import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/car_transaction.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/my_car_colors.dart';
import '../../utils/transaction_chart_utils.dart';
import '../empty_state.dart';
import '../stat_card.dart';

/// Tab "Gráficos": ingresos y egresos por día con selector de período.
class CarChartsTab extends StatefulWidget {
  final List<CarTransaction> transactions;
  final bool isLoading;

  const CarChartsTab({
    super.key,
    required this.transactions,
    required this.isLoading,
  });

  @override
  State<CarChartsTab> createState() => _CarChartsTabState();
}

class _CarChartsTabState extends State<CarChartsTab> {
  ChartPeriod _period = ChartPeriod.all;

  static const _periodLabels = {
    ChartPeriod.sevenDays: '7 días',
    ChartPeriod.thirtyDays: '30 días',
    ChartPeriod.all: 'Todos',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.transactions.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No hay movimientos',
        message: 'Debes registrar movimientos para ver los gráficos',
      );
    }

    final data = groupTransactionsByDay(widget.transactions, _period);
    final summary = TransactionSummary.of(
      filterByPeriod(widget.transactions, _period),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 40,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final period in ChartPeriod.values) ...[
                  if (period != ChartPeriod.values.first)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _PeriodChip(
                      label: _periodLabels[period]!,
                      isSelected: _period == period,
                      onTap: () => setState(() => _period = period),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            if (data.isEmpty)
              const SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'No hay datos para este período',
                  message:
                      'Intenta seleccionar "Todos" para ver todos los movimientos',
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Ingresos',
                      value: CurrencyFormatter.format(summary.income),
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Egresos',
                      value: CurrencyFormatter.format(summary.expense),
                      icon: Icons.arrow_upward_rounded,
                      valueColor: MyCarColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatCard(
                label: 'Balance',
                value: CurrencyFormatter.format(summary.balance),
                icon: Icons.account_balance_wallet_outlined,
                valueColor: summary.balance >= 0
                    ? MyCarColors.success
                    : MyCarColors.error,
              ),
              const SizedBox(height: 24),
              const _ChartLegend(),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: data.length > 5
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: data.length * 64.0,
                          height: 300,
                          child: BarChart(_barChartData(data)),
                        ),
                      )
                    : BarChart(_barChartData(data)),
              ),
              if (summary.expenseByCategory.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ExpenseBreakdown(byCategory: summary.expenseByCategory),
              ],
            ],
          ],
        ),
      ),
    );
  }

  BarChartData _barChartData(List<DayTotals> data) {
    final maxValue = data
        .map((e) => e.income > e.expense ? e.income : e.expense)
        .reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue == 0 ? 1 : maxValue) * 1.2;
    final yInterval = maxY / 5;
    const axisLabelStyle = TextStyle(
      color: MyCarColors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.grey.shade800,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            if (groupIndex < 0 || groupIndex >= data.length) {
              return BarTooltipItem('', const TextStyle());
            }
            final entry = data[groupIndex];
            return BarTooltipItem(
              '${DateFormat('dd/MM').format(entry.day)}\n'
              '${rodIndex == 0 ? 'Ingreso' : 'Egreso'}: '
              '${CurrencyFormatter.format(rodIndex == 0 ? entry.income : entry.expense)}',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) return const Text('');
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('dd/MM').format(data[index].day),
                  style: axisLabelStyle,
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: yInterval,
            getTitlesWidget: (value, meta) {
              if (value < 0) return const Text('');
              return Text(
                CurrencyFormatter.format(value),
                style: axisLabelStyle,
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: MyCarColors.border, width: 1),
          left: BorderSide(color: MyCarColors.border, width: 1),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        getDrawingHorizontalLine: (_) => FlLine(
          color: MyCarColors.border.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      ),
      barGroups: [
        for (var i = 0; i < data.length; i++)
          BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: data[i].income,
                color: MyCarColors.success,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: data[i].expense,
                color: MyCarColors.error,
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: MyCarColors.textSecondary,
          ),
        ),
      ],
    );

    return Row(
      children: [
        item(MyCarColors.success, 'Ingresos'),
        const SizedBox(width: 16),
        item(MyCarColors.error, 'Egresos'),
      ],
    );
  }
}

class _ExpenseBreakdown extends StatelessWidget {
  final Map<TransactionCategory, double> byCategory;

  const _ExpenseBreakdown({required this.byCategory});

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Egresos por categoría',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: MyCarColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key.label),
                Text(
                  CurrencyFormatter.format(entry.value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MyCarColors.secondary.withValues(alpha: 0.1)
              : MyCarColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? MyCarColors.secondary : MyCarColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? MyCarColors.secondary
                  : MyCarColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
