import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'notification_service.dart';

/// Operaciones sobre la cuenta del usuario. Abstracción para poder probar
/// `AuthProvider` sin Supabase.
abstract class AccountService {
  /// Elimina definitivamente la cuenta y todos sus datos. Lanza si falla.
  Future<void> deleteAccount();
}

/// Elimina la cuenta con la función `delete_my_account()` de Supabase (ver
/// `docs/SUPABASE_DELETE_ACCOUNT_MIGRATION.md`) y limpia el estado local.
class SupabaseAccountService implements AccountService {
  @override
  Future<void> deleteAccount() async {
    final client = SupabaseConfig.client;
    if (client.auth.currentUser == null) {
      throw StateError('No hay una sesión activa');
    }

    await client.rpc('delete_my_account');
    await _clearLocalState(client);
  }

  /// Limpieza local: cada paso es opcional y no debe impedir terminar
  /// (la cuenta ya fue eliminada en el servidor).
  Future<void> _clearLocalState(SupabaseClient client) async {
    await _bestEffort('notificaciones', () async {
      await NotificationService.instance.cancelAllNotifications();
    });
    await _bestEffort('RevenueCat', () async {
      if (!await Purchases.isAnonymous) await Purchases.logOut();
    });
    await _bestEffort('preferencias', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    });
    // Alcance local: el usuario ya no existe, no hay sesión que cerrar en el servidor
    await _bestEffort('sesión', () async {
      await client.auth.signOut(scope: SignOutScope.local);
    });
  }

  Future<void> _bestEffort(String step, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('No se pudo limpiar $step tras eliminar la cuenta: $e');
    }
  }
}
