---
name: account-deletion
description: Eliminación de cuenta desde la app (requisito de Apple 5.1.1(v)). Úsalo al tocar el botón "Eliminar cuenta" de Ajustes, AuthProvider.deleteAccount, AccountService o la función SQL delete_my_account.
---

# Eliminar cuenta

Ajustes → **Eliminar cuenta**. Borra la cuenta y todos los datos del usuario en Supabase y limpia el estado local.

## Flujo
1. `SettingsScreen` abre `DeleteAccountDialog` (`lib/widgets/delete_account_dialog.dart`): explica que es permanente, qué se
   borra y que **no cancela** la suscripción de App Store/Google Play; el botón se habilita al escribir `ELIMINAR`
   (sin importar mayúsculas ni espacios).
2. Con confirmación, muestra un progreso y llama `AuthProvider.deleteAccount()`.
3. `AuthProvider` delega en `AccountService` (inyectable por constructor: `AuthProvider(accountService: ...)`).
4. `SupabaseAccountService` (`lib/services/account_service.dart`) llama al RPC `delete_my_account` y después limpia lo
   local, cada paso en modo "mejor esfuerzo" (no impide terminar): cancela notificaciones programadas, `Purchases.logOut()`
   (si no es anónimo), borra `user_id` de SharedPreferences y cierra la sesión con `SignOutScope.local`.
5. Éxito → `context.go('/login')` + mensaje "Tu cuenta fue eliminada". Fallo → mensaje genérico en español
   (`errorMessage`); el detalle técnico solo va al log.

## Servidor
`docs/SUPABASE_DELETE_ACCOUNT_MIGRATION.md`: función `public.delete_my_account()` con `SECURITY DEFINER`, solo ejecutable por
`authenticated`, que borra `alerts` (por si su FK no tiene cascade) y luego `auth.users` del `auth.uid()`; el resto de
tablas se borra en cascada. **Hay que ejecutarla en Supabase antes de publicar**; sin ella el botón siempre falla.
Si se agrega una tabla nueva con `user_id`, debe referenciar `auth.users ON DELETE CASCADE` (o borrarse explícitamente en la función).

## Tests
- `test/providers/auth_provider_delete_account_test.dart`: éxito, `isLoading`, fallo, mensaje sin detalle técnico, reintento.
- `test/widgets/delete_account_dialog_test.dart`: botón deshabilitado hasta escribir la palabra, mayúsculas/espacios, confirmar,
  cancelar y cerrar fuera.
- No cubierto por tests: `SupabaseAccountService` (llama a Supabase/RevenueCat reales) y el flujo de `SettingsScreen`
  (depende de varios providers y servicios). Verificar a mano con un usuario de prueba.

## Pendiente
- Cancelar la suscripción no es posible desde la app (lo hace el usuario en la tienda); solo se avisa.
- Usuarios que entraron con Apple (skill `social-auth`): Apple exige revocar su token al eliminar la cuenta; hoy no se hace
  (requiere una Edge Function con la clave `.p8`). Ver `docs/SOCIAL_AUTH_SETUP.md`.
