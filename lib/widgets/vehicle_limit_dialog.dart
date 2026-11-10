import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/my_car_colors.dart';

/// Aviso de que el plan mensual llegó a su tope de vehículos, con acceso directo
/// a los planes (el anual no tiene tope).
class VehicleLimitDialog extends StatelessWidget {
  final int limit;

  const VehicleLimitDialog({super.key, required this.limit});

  static Future<void> show(BuildContext context, {required int limit}) =>
      showDialog<void>(
        context: context,
        builder: (_) => VehicleLimitDialog(limit: limit),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Llegaste al límite de vehículos'),
      content: Text(
        'Tu plan mensual permite hasta $limit vehículos. '
        'Con el plan anual puedes agregar vehículos ilimitados.',
      ),
      actions: [
        TextButton(
          key: const Key('vehicle_limit_dismiss'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          key: const Key('vehicle_limit_see_plans'),
          style: FilledButton.styleFrom(
            backgroundColor: MyCarColors.primary,
            foregroundColor: MyCarColors.white,
          ),
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push('/subscription');
          },
          child: const Text('Ver planes'),
        ),
      ],
    );
  }
}
