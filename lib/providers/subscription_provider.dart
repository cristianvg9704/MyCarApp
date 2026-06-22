import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService.instance;

  bool _isLoading = false;
  List<Package> _availablePackages = [];
  String? _errorMessage;

  bool get isLoading => _isLoading || _subscriptionService.isLoading;
  List<Package> get availablePackages => _availablePackages;
  SubscriptionTier get currentTier => _subscriptionService.currentTier;
  bool get isPremium => _subscriptionService.isPremium;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _subscriptionService.initialize();
      await loadPackages();
    } catch (e) {
      _errorMessage = 'Error al inicializar suscripciones: $e';
      debugPrint('❌ $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPackages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availablePackages = await _subscriptionService.getAvailablePackages();
      if (_availablePackages.isEmpty) {
        _errorMessage =
            'No hay paquetes disponibles. Verifica la configuración en RevenueCat.';
      }
    } catch (e) {
      _errorMessage = 'Error al cargar paquetes: $e';
      debugPrint('❌ $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> purchasePackage(Package package) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _subscriptionService.purchasePackage(package);
      if (success) {
        notifyListeners();
      } else {
        _errorMessage = 'No se pudo completar la compra';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al realizar compra: $e';
      debugPrint('❌ $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _subscriptionService.restorePurchases();
      if (success) {
        notifyListeners();
      } else {
        _errorMessage = 'No se encontraron compras para restaurar';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al restaurar compras: $e';
      debugPrint('❌ $_errorMessage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkSubscriptionStatus() async {
    await _subscriptionService.checkSubscriptionStatus();
    notifyListeners();
  }
}
