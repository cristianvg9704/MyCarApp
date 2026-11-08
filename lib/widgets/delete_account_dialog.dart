import 'package:flutter/material.dart';
import '../utils/my_car_colors.dart';

/// Confirmación para eliminar la cuenta: explica qué se borra y exige escribir
/// [confirmationWord] para habilitar el botón.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  static const String confirmationWord = 'ELIMINAR';

  /// Devuelve true solo si el usuario confirmó.
  static Future<bool> show(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    return confirmed ?? false;
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();

  bool get _confirmed =>
      _controller.text.trim().toUpperCase() ==
      DeleteAccountDialog.confirmationWord;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción es permanente y no se puede deshacer. Se borrarán '
              'tu cuenta y todos tus datos: vehículos, ingresos y egresos, '
              'kilometraje, viajes, mantenimientos y alertas.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Si tienes una suscripción activa, cancélala por separado en los '
              'ajustes de App Store o Google Play: eliminar la cuenta no '
              'detiene el cobro.',
              style: TextStyle(color: MyCarColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Escribe ELIMINAR para confirmar',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: MyCarColors.error),
          child: const Text('Eliminar cuenta'),
        ),
      ],
    );
  }
}
