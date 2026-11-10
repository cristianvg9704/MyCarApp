import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/delete_account_dialog.dart';
import 'my_car_colors.dart';

/// Cierra sesión y vuelve al login.
Future<void> signOutAndGoToLogin(BuildContext context) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final router = GoRouter.of(context);
  await authProvider.signOut();
  router.go('/login');
}

/// Pide confirmación y elimina la cuenta y sus datos (requisito de Apple
/// 5.1.1(v)). Se usa desde Ajustes y desde la pantalla de planes, para que un
/// usuario sin suscripción también pueda eliminarla. Ver skill
/// `account-deletion`.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final confirmed = await DeleteAccountDialog.show(context);
  if (!confirmed || !context.mounted) return;

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  final deleted = await authProvider.deleteAccount();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // cierra el progreso

  if (deleted) {
    router.go('/login');
    messenger.showSnackBar(
      const SnackBar(content: Text('Tu cuenta fue eliminada')),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          authProvider.errorMessage ?? 'No se pudo eliminar la cuenta',
        ),
        backgroundColor: MyCarColors.error,
      ),
    );
  }
}
