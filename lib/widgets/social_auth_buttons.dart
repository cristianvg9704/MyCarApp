import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/social_auth_service.dart';
import '../utils/my_car_colors.dart';

/// Separador "o continúa con" y botones para Apple y Google. Sirven tanto para
/// iniciar sesión como para crear la cuenta.
class SocialAuthButtons extends StatelessWidget {
  /// Se llama con el proveedor elegido.
  final void Function(SocialProvider provider) onPressed;

  /// Apple solo se ofrece donde está disponible (iOS y macOS).
  final bool showApple;

  final bool enabled;

  const SocialAuthButtons({
    super.key,
    required this.onPressed,
    required this.showApple,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: MyCarColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o continúa con',
                style: TextStyle(
                  color: MyCarColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: Divider(color: MyCarColors.border)),
          ],
        ),
        const SizedBox(height: 16),
        if (showApple) ...[
          // Botón oficial: Apple exige su estilo y su logotipo
          SignInWithAppleButton(
            text: 'Continuar con Apple',
            height: 52,
            borderRadius: BorderRadius.circular(14),
            onPressed: enabled ? () => onPressed(SocialProvider.apple) : null,
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: enabled ? () => onPressed(SocialProvider.google) : null,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text(
            'Continuar con Google',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: MyCarColors.textPrimary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: MyCarColors.border, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}
