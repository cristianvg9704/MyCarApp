import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/account_service.dart';
import '../services/social_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final AccountService _accountService;
  final SocialAuthService _socialAuth;
  bool _isLoading = false;
  String? _errorMessage;

  /// Se llama con el id del usuario cuando inicia sesión, y sin argumentos al
  /// cerrarla. La app los usa para asociar las compras (RevenueCat) a la cuenta.
  final Future<void> Function(String userId)? _onSignedIn;
  final Future<void> Function()? _onSignedOut;
  final String? Function()? _currentUserId;

  AuthProvider({
    AccountService? accountService,
    SocialAuthService? socialAuthService,
    Future<void> Function(String userId)? onSignedIn,
    Future<void> Function()? onSignedOut,
    String? Function()? currentUserId,
  }) : _accountService = accountService ?? SupabaseAccountService(),
       _socialAuth = socialAuthService ?? DeviceSocialAuthService(),
       _onSignedIn = onSignedIn,
       _onSignedOut = onSignedOut,
       _currentUserId = currentUserId;

  Future<void> _notifySignedIn(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    try {
      await _onSignedIn?.call(userId);
    } catch (e) {
      debugPrint('Error al asociar la cuenta con las compras: $e');
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _supabase.auth.currentSession != null;
  User? get currentUser => _supabase.auth.currentUser;

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
        },
      );

      if (response.user != null) {
        if (response.session != null) await _notifySignedIn(response.user!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _setError('Error al crear la cuenta');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verifica si un correo ya existe en Supabase
  Future<bool> _checkEmailExists(String email) async {
    try {
      // Intentar consultar la tabla auth.users (requiere permisos apropiados)
      // Si esto no funciona, usaremos el error del sign-up como fallback
      final response = await _supabase
          .from('auth.users')
          .select('id')
          .eq('email', email.toLowerCase())
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      // Si no podemos acceder directamente a auth.users, retornar false
      // y dejar que Supabase maneje el error en signUp
      debugPrint('No se pudo verificar email en auth.users: $e');
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // El plan debe estar al día antes de decidir a dónde va el usuario.
        await _notifySignedIn(response.user!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _setError('Credenciales inválidas');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Si el proveedor social se puede usar en este dispositivo (Apple solo en
  /// iOS y macOS).
  bool isSocialProviderAvailable(SocialProvider provider) =>
      _socialAuth.isAvailable(provider);

  /// Inicia sesión (o crea la cuenta) con Apple o Google. Devuelve true si
  /// quedó una sesión abierta. Si el usuario cancela devuelve false sin dejar
  /// mensaje de error; si falla, deja el motivo en [errorMessage].
  Future<bool> signInWithSocial(SocialProvider provider) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _socialAuth.signIn(provider);
      if (result == SocialSignInResult.signedIn) {
        await _notifySignedIn(
          _currentUserId != null ? _currentUserId() : currentUser?.id,
        );
      }
      _isLoading = false;
      notifyListeners();
      return result == SocialSignInResult.signedIn;
    } on SocialAuthException catch (e) {
      _isLoading = false;
      _setError(e.message);
      return false;
    } catch (e) {
      debugPrint('Error en inicio de sesión social: $e');
      _isLoading = false;
      _setError('No se pudo iniciar sesión. Intenta de nuevo.');
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      await _supabase.auth.resetPasswordForEmail(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_getErrorMessage(e));
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.auth.signOut();
      try {
        await _onSignedOut?.call();
      } catch (e) {
        debugPrint('Error al desvincular las compras: $e');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError(_getErrorMessage(e));
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina la cuenta del usuario y todos sus datos. Devuelve true si se
  /// eliminó; si falla deja el mensaje en [errorMessage].
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _accountService.deleteAccount();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error eliminando la cuenta: $e');
      _isLoading = false;
      _setError('No se pudo eliminar la cuenta. Intenta de nuevo.');
      return false;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();

      // Detectar errores de email duplicado (solo en inglés)
      if (message.contains('already registered') ||
          message.contains('user already exists') ||
          message.contains('duplicate') ||
          message.contains('email already registered')) {
        return 'Este correo electrónico ya está registrado. Por favor usa otro correo o inicia sesión si ya tienes una cuenta.';
      }

      return error.message;
    }
    return error.toString();
  }

  // Obtener metadata del usuario actual
  Map<String, dynamic>? getCurrentUserMetadata() {
    return currentUser?.userMetadata;
  }

  // Escuchar cambios en el estado de autenticación
  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        notifyListeners();
      }
    });
  }
}
