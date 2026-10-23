import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/income.dart';
import '../../utils/income_chart_utils.dart';
import '../../utils/my_car_colors.dart';
import '../empty_state.dart';
import '../stat_card.dart';

/// Tab "Gráficos": ingresos por día con selector de período.
class CarChartsTab extends StatefulWidget {
  final List<Income> incomes;
  final bool isLoading;

  const CarChartsTab({
    super.key,
    required this.incomes,
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

    if (widget.incomes.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No hay ingresos',
        message: 'Debes agregar ingresos para ver los gráficos',
      );
    }

    final data = groupIncomesByDay(widget.incomes, _period);
    final total = data.fold<double>(0, (sum, e) => sum + e.value);
    final average = data.isNotEmpty ? total / data.length : 0.0;

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
                      'Intenta seleccionar "Todos" para ver todos los ingresos',
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total',
                      value: '\$${NumberFormat('#,##0.00').format(total)}',
                      icon: Icons.attach_money,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Promedio',
                      value: '\$${NumberFormat('#,##0.00').format(average)}',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 320,
                child: data.length > 7
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: data.length * 50.0,
                          height: 300,
                          child: BarChart(_barChartData(data)),
                        ),
                      )
                    : BarChart(_barChartData(data)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BarChartData _barChartData(List<MapEntry<DateTime, double>> data) {
    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;
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
              '${DateFormat('dd/MM').format(entry.key)}\n'
              '\$${NumberFormat('#,##0.00').format(entry.value)}',
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
                  DateFormat('dd/MM').format(data[index].key),
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
                '\$${NumberFormat('#,##0').format(value)}',
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
            barRods: [
              BarChartRodData(
                toY: data[i].value,
                color: MyCarColors.success,
                width: 20,
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
