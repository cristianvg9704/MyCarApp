import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;
import '../config/supabase_config.dart';

class UserProvider extends ChangeNotifier {
  app_models.User? _user;
  bool _isLoading = false;

  app_models.User? get user => _user;
  bool get isLoading => _isLoading;
  String get userName => _user?.name ?? 'Usuario';
  String get userEmail => _user?.email ?? 'usuario@ejemplo.com';
  String get userPhone => _user?.phone ?? '+1 234 567 8900';
  String? get userPhotoPath => _user?.photoPath;

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Intentar cargar desde Supabase primero
      final supabase = SupabaseConfig.client;
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser != null) {
        // Cargar desde metadata de Supabase
        final metadata = currentUser.userMetadata;
        final email = currentUser.email ?? 'usuario@ejemplo.com';
        final name = metadata?['name'] as String? ?? 'Usuario';
        final phone = metadata?['phone'] as String? ?? '+1 234 567 8900';
        
        _user = app_models.User(
          id: currentUser.id.hashCode, // Usar hash del ID de Supabase como ID local
          name: name,
          email: email,
          phone: phone,
          photoPath: metadata?['photo_path'] as String?,
        );
      } else {
        // Si no hay usuario autenticado, crear usuario por defecto local
        _user = app_models.User(
          name: 'Usuario',
          email: 'usuario@ejemplo.com',
          phone: '+1 234 567 8900',
        );
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(app_models.User user) async {
    try {
      // Actualizar en Supabase si está autenticado
      final supabase = SupabaseConfig.client;
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser != null) {
        // Actualizar metadata en Supabase
        final updatedMetadata = <String, dynamic>{
          'name': user.name,
          'phone': user.phone,
        };
        if (user.photoPath != null) {
          updatedMetadata['photo_path'] = user.photoPath;
        }
        
        await supabase.auth.updateUser(
          UserAttributes(data: updatedMetadata),
        );
        
        // Actualizar estado local
        final updatedUser = app_models.User(
          id: _user?.id ?? currentUser.id.hashCode,
          name: user.name,
          email: user.email,
          phone: user.phone,
          photoPath: user.photoPath,
        );
        _user = updatedUser;
        notifyListeners();
      } else {
        // Si no hay usuario autenticado, solo actualizar estado local
        final updatedUser = app_models.User(
          id: _user?.id ?? 0,
          name: user.name,
          email: user.email,
          phone: user.phone,
          photoPath: user.photoPath,
        );
        _user = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> updateName(String name) async {
    if (_user != null) {
      final updatedUser = app_models.User(
        id: _user!.id,
        name: name,
        email: _user!.email,
        phone: _user!.phone,
        photoPath: _user!.photoPath,
      );
      await updateUser(updatedUser);
    }
  }

  Future<void> updateEmail(String email) async {
    if (_user != null) {
      final updatedUser = app_models.User(
        id: _user!.id,
        name: _user!.name,
        email: email,
        phone: _user!.phone,
      );
      await updateUser(updatedUser);
    }
  }

  Future<void> updatePhone(String phone) async {
    if (_user != null) {
      final updatedUser = app_models.User(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phone: phone,
        photoPath: _user!.photoPath,
      );
      await updateUser(updatedUser);
    }
  }

  Future<void> updatePhoto(String? photoPath) async {
    if (_user != null) {
      final updatedUser = app_models.User(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        phone: _user!.phone,
        photoPath: photoPath,
      );
      await updateUser(updatedUser);
    }
  }
}
