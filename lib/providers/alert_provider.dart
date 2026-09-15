import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

class AlertProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _selectedCarId;
  String _filter = 'all'; // 'all', 'pending', 'upcoming', 'completed'

  List<Alert> get alerts => _getFilteredAlerts();
  List<Alert> get allAlerts => _alerts; // Todas las alertas sin filtrar
  bool get isLoading => _isLoading;
  String? get selectedCarId => _selectedCarId;
  String get filter => _filter;

  List<Alert> _getFilteredAlerts() {
    List<Alert> filtered = _alerts;

    // Filtrar por vehículo si está seleccionado
    if (_selectedCarId != null) {
      filtered = filtered.where((alert) => alert.carId == _selectedCarId).toList();
    }

    // Aplicar filtro de estado
    switch (_filter) {
      case 'pending':
        filtered = filtered.where((alert) => !alert.isCompleted).toList();
        break;
      case 'upcoming':
        final now = DateTime.now();
        // Normalizar la fecha actual para comparar solo fechas (sin hora)
        final today = DateTime(now.year, now.month, now.day);
        final nextWeek = today.add(const Duration(days: 7));
        filtered = filtered.where((alert) {
          // Normalizar la fecha de la alerta para comparar solo fechas (sin hora)
          final alertDate = DateTime(
            alert.alertDate.year,
            alert.alertDate.month,
            alert.alertDate.day,
          );
          return !alert.isCompleted &&
              (alertDate.isAfter(today) || alertDate.isAtSameMomentAs(today)) &&
              alertDate.isBefore(nextWeek);
        }).toList();
        break;
      case 'completed':
        filtered = filtered.where((alert) => alert.isCompleted).toList();
        break;
      case 'all':
      default:
        // No filtrar por estado
        break;
    }

    // Ordenar por fecha
    filtered.sort((a, b) => a.alertDate.compareTo(b.alertDate));

    return filtered;
  }

  Future<void> loadAlerts({bool syncNotifications = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _alerts = await _dbHelper.getAllAlerts();
      if (syncNotifications) {
        await syncPendingNotifications();
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reprograma notificaciones locales para alertas pendientes (p. ej. al abrir la app)
  Future<void> syncPendingNotifications() async {
    try {
      final pending = _alerts.where((alert) => !alert.isCompleted).toList();
      await NotificationService.instance.scheduleAllPendingAlerts(pending);
    } catch (e) {
      debugPrint('Error sincronizando notificaciones pendientes: $e');
    }
  }

  Future<void> loadAlertsByCar(String carId) async {
    _selectedCarId = carId;
    _isLoading = true;
    notifyListeners();

    try {
      _alerts = await _dbHelper.getAlertsByCar(carId);
    } catch (e) {
      debugPrint('Error loading alerts by car: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUpcomingAlerts({int days = 7}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _alerts = await _dbHelper.getUpcomingAlerts(days: days);
    } catch (e) {
      debugPrint('Error loading upcoming alerts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSelectedCar(String? carId) {
    _selectedCarId = carId;
    notifyListeners();
  }

  Future<void> addAlert(Alert alert) async {
    try {
      final alertId = await _dbHelper.insertAlert(alert);
      // Programar notificación
      try {
        final alertWithId = alert.copyWith(id: alertId);
        await NotificationService.instance.scheduleAlertNotification(alertWithId);
      } catch (e) {
        debugPrint('Error programando notificación: $e');
      }
      await loadAlerts();
    } catch (e) {
      debugPrint('Error adding alert: $e');
      rethrow;
    }
  }

  Future<void> updateAlert(Alert alert) async {
    try {
      await _dbHelper.updateAlert(alert);
      // Actualizar notificación
      try {
        await NotificationService.instance.updateAlertNotification(alert);
      } catch (e) {
        debugPrint('Error actualizando notificación: $e');
      }
      await loadAlerts();
    } catch (e) {
      debugPrint('Error updating alert: $e');
      rethrow;
    }
  }

  Future<void> deleteAlert(String id) async {
    try {
      final alert = _alerts.firstWhere((a) => a.id == id);
      // Cancelar notificación
      try {
        await NotificationService.instance.cancelNotification(alert);
      } catch (e) {
        debugPrint('Error cancelando notificación: $e');
      }
      await _dbHelper.deleteAlert(id);
      await loadAlerts();
    } catch (e) {
      debugPrint('Error deleting alert: $e');
      rethrow;
    }
  }

  Future<void> completeAlert(String id) async {
    try {
      final alert = _alerts.firstWhere((a) => a.id == id);
      
      // Completar la alerta actual
      await _dbHelper.completeAlert(id);
      
      // Si es recurrente, crear próxima instancia
      if (alert.isRecurring && alert.recurrenceType != null) {
        final nextDate = alert.getNextRecurrenceDate();
        if (nextDate != null) {
          final nextAlert = alert.copyWith(
            id: null, // Nuevo ID será generado por Supabase
            alertDate: nextDate,
            isCompleted: false,
            completedAt: null,
            createdAt: null,
            updatedAt: null,
          );
          final nextAlertId = await _dbHelper.insertAlert(nextAlert);
          // Programar notificación para la próxima instancia
          try {
            final nextAlertWithId = nextAlert.copyWith(id: nextAlertId);
            await NotificationService.instance.scheduleAlertNotification(nextAlertWithId);
          } catch (e) {
            debugPrint('Error programando notificación para próxima instancia: $e');
          }
        }
      }
      
      // Cancelar notificación de la alerta completada
      try {
        await NotificationService.instance.cancelNotification(alert);
      } catch (e) {
        debugPrint('Error cancelando notificación: $e');
      }
      
      await loadAlerts();
    } catch (e) {
      debugPrint('Error completing alert: $e');
      rethrow;
    }
  }

  int get pendingCount => _alerts.where((alert) => !alert.isCompleted).length;
  int get upcomingCount {
    final now = DateTime.now();
    // Normalizar la fecha actual para comparar solo fechas (sin hora)
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));
    return _alerts.where((alert) {
      // Normalizar la fecha de la alerta para comparar solo fechas (sin hora)
      final alertDate = DateTime(
        alert.alertDate.year,
        alert.alertDate.month,
        alert.alertDate.day,
      );
      return !alert.isCompleted &&
          (alertDate.isAfter(today) || alertDate.isAtSameMomentAs(today)) &&
          alertDate.isBefore(nextWeek);
    }).length;
  }
}
