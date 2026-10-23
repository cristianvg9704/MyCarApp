import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/car.dart';
import '../../utils/my_car_colors.dart';
import '../../utils/vehicle_image_helper.dart';

/// Tab "Detalle": imagen e información general del vehículo.
class CarInfoTab extends StatelessWidget {
  final Car car;

  const CarInfoTab({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _CarImage(imageBase64: car.imageBase64),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Año', value: '${car.year}'),
                if (car.plateNumber != null) ...[
                  const SizedBox(height: 16),
                  _InfoRow(label: 'Placa', value: car.plateNumber!),
                ],
                if (car.color != null) ...[
                  const SizedBox(height: 16),
                  _InfoRow(label: 'Color', value: car.color!),
                ],
                if (car.purchaseDate != null) ...[
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: 'Fecha de Compra',
                    value: DateFormat('dd/MM/yyyy').format(car.purchaseDate!),
                  ),
                ],
                if (car.purchasePrice != null) ...[
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: 'Precio de Compra',
                    value: '\$${NumberFormat('#,##0.00').format(car.purchasePrice)}',
                  ),
                ],
                if (car.notes != null && car.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'Notas',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MyCarColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    car.notes!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MyCarColors.textPrimary,
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MyCarColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: MyCarColors.textPrimary,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _CarImage extends StatelessWidget {
  final String? imageBase64;

  const _CarImage({required this.imageBase64});

  static const double _height = 240;

  @override
  Widget build(BuildContext context) {
    final bytes = VehicleImage.decode(imageBase64);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CarPlaceholder(),
      );
    }
    return const _CarPlaceholder();
  }
}

class _CarPlaceholder extends StatelessWidget {
  const _CarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/car1 test.jpeg',
      width: double.infinity,
      height: _CarImage._height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: double.infinity,
        height: _CarImage._height,
        decoration: const BoxDecoration(gradient: MyCarColors.primaryGradient),
        child: const Icon(Icons.directions_car, color: Colors.white, size: 80),
      ),
    );
  }
}
