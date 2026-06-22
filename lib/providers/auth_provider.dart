import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;
  bool _isLoading = false;
  String? _errorMessage;

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

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _clearError();
      notifyListeners();

      await _supabase.auth.resetPasswordForEmail(email);

      await _supabase.auth.signOut();

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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError(_getErrorMessage(e));
      _isLoading = false;
      notifyListeners();
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
