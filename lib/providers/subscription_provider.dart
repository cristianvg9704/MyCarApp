import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';
import '../utils/subscription_management.dart';

class SubscriptionProvider extends ChangeNotifier {
  /// [fetchManagementUrl], [launchUri] y [platform] se pueden sustituir para
  /// probar "Administrar suscripción" sin RevenueCat ni abrir el navegador.
  SubscriptionProvider({
    Future<String?> Function()? fetchManagementUrl,
    Future<bool> Function(Uri uri)? launchUri,
    TargetPlatform? platform,
  }) : _fetchManagementUrl =
           fetchManagementUrl ?? SubscriptionService.instance.getManagementUrl,
       _launchUri =
           launchUri ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _platform = platform;

  final SubscriptionService _subscriptionService = SubscriptionService.instance;
  final Future<String?> Function() _fetchManagementUrl;
  final Future<bool> Function(Uri uri) _launchUri;
  final TargetPlatform? _platform;

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

  /// Abre la pantalla de la tienda donde el usuario cancela o cambia su plan.
  /// Devuelve `false` si no hay tienda disponible o no se pudo abrir.
  Future<bool> openManageSubscription() async {
    final url = subscriptionManagementUrl(
      managementUrl: await _fetchManagementUrl(),
      platform: _platform ?? defaultTargetPlatform,
    );
    if (url == null) return false;

    try {
      return await _launchUri(Uri.parse(url));
    } catch (e) {
      debugPrint('❌ No se pudo abrir la administración de suscripción: $e');
      return false;
    }
  }

  Future<void> checkSubscriptionStatus() async {
    await _subscriptionService.checkSubscriptionStatus();
    notifyListeners();
  }
}
