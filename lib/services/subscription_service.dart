import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionTier { free, monthly, yearly }

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._internal();
  SubscriptionService._internal();

  bool _initialized = false;
  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _isLoading = false;

  SubscriptionTier get currentTier => _currentTier;
  bool get isLoading => _isLoading;
  bool get isPremium =>
      _currentTier == SubscriptionTier.monthly ||
      _currentTier == SubscriptionTier.yearly;

  static const String monthlyProductId = 'rc_monthly';
  static const String yearlyProductId = 'rc_annual';
  static const String revenueCatApiKey = 'appl_XSstkcbOunhySDJeJHunVqWnGNK';

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Platform-specific API keys (usando la misma key para ambas plataformas en modo test)
      String apiKey;
      if (Platform.isIOS) {
        apiKey = revenueCatApiKey;
      } else if (Platform.isAndroid) {
        apiKey = revenueCatApiKey;
      } else {
        debugPrint('⚠️ RevenueCat solo está disponible en Android e iOS');
        return;
      }

      // Configurar RevenueCat primero
      await Purchases.configure(PurchasesConfiguration(apiKey));

      // Luego configurar el log level (después de configure)
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        await Purchases.logIn(userId);
      }

      await _loadSubscriptionStatus();
      _initialized = true;
      debugPrint('✅ SubscriptionService inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error al inicializar SubscriptionService: $e');
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await _updateSubscriptionTier(customerInfo);
    } catch (e) {
      debugPrint('⚠️ Error al cargar estado de suscripción: $e');
    }
  }

  Future<void> _updateSubscriptionTier(CustomerInfo customerInfo) async {
    final prefs = await SharedPreferences.getInstance();

    // Verificar entitlement 'MyCarApp Pro' como sugiere RevenueCat
    final hasPro = customerInfo.entitlements.active.containsKey('MyCarApp Pro');

    if (hasPro) {
      // Si tiene el entitlement activo, verificar qué producto lo activó
      final proEntitlement = customerInfo.entitlements.active['MyCarApp Pro'];
      final productId = proEntitlement?.productIdentifier ?? '';

      if (productId.contains('monthly') ||
          productId.contains('rc_monthly') ||
          productId == monthlyProductId) {
        _currentTier = SubscriptionTier.monthly;
        await prefs.setString('subscription_tier', 'monthly');
      } else if (productId.contains('yearly') ||
          productId.contains('rc_annual') ||
          productId == yearlyProductId) {
        _currentTier = SubscriptionTier.yearly;
        await prefs.setString('subscription_tier', 'yearly');
      } else {
        // Si tiene el entitlement pero no podemos determinar el tipo, asumir mensual
        _currentTier = SubscriptionTier.monthly;
        await prefs.setString('subscription_tier', 'monthly');
      }
    } else {
      _currentTier = SubscriptionTier.free;
      await prefs.setString('subscription_tier', 'free');
    }
  }

  /// Verifica si el usuario tiene el entitlement 'MyCarApp Pro' activo
  Future<bool> hasProEntitlement() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('MyCarApp Pro');
    } catch (e) {
      debugPrint('❌ Error al verificar entitlement: $e');
      return false;
    }
  }

  Future<List<Package>> getAvailablePackages() async {
    try {
      debugPrint('🔍 Obteniendo offerings de RevenueCat...');
      debugPrint(
        '📱 Plataforma: ${Platform.isIOS
            ? "iOS"
            : Platform.isAndroid
            ? "Android"
            : "Unknown"}',
      );
      debugPrint('');
      debugPrint('⚠️ IMPORTANTE PARA iOS:');
      debugPrint(
        '   - StoreKit Configuration SOLO funciona cuando ejecutas desde Xcode',
      );
      debugPrint(
        '   - Si ejecutas con "flutter run", NO usará el archivo StoreKit',
      );
      debugPrint(
        '   - Para probar StoreKit: abre ios/Runner.xcworkspace y ejecuta desde Xcode (⌘R)',
      );
      debugPrint('');

      final offerings = await Purchases.getOfferings();

      debugPrint('📦 Offerings obtenidos:');
      debugPrint(
        '  - Current offering: ${offerings.current?.identifier ?? "null"}',
      );
      debugPrint('  - All offerings: ${offerings.all.keys.toList()}');

      // Intentar obtener el offering "current" primero
      Offering? selectedOffering = offerings.current;

      // Si no hay current, buscar el offering específico por ID
      if (selectedOffering == null) {
        const String offeringId = 'app308072b107';
        if (offerings.all.containsKey(offeringId)) {
          selectedOffering = offerings.all[offeringId];
          debugPrint('✅ Usando offering específico: $offeringId');
        } else if (offerings.all.isNotEmpty) {
          // Si no encontramos el específico, usar el primer offering disponible
          selectedOffering = offerings.all.values.first;
          debugPrint(
            '✅ Usando primer offering disponible: ${selectedOffering.identifier}',
          );
        }
      }

      if (selectedOffering != null) {
        final packages = selectedOffering.availablePackages;
        debugPrint('✅ Paquetes disponibles: ${packages.length}');

        if (packages.isEmpty) {
          debugPrint(
            '⚠️ El offering "${selectedOffering.identifier}" no tiene paquetes',
          );
          debugPrint(
            '⚠️ Verifica en RevenueCat que el offering tenga productos agregados',
          );
        } else {
          for (var package in packages) {
            debugPrint('  - Package ID: ${package.identifier}');
            debugPrint('    Product ID: ${package.storeProduct.identifier}');
            debugPrint('    Title: ${package.storeProduct.title}');
            debugPrint('    Price: ${package.storeProduct.priceString}');
          }
        }

        return packages;
      } else {
        debugPrint('⚠️ No hay offering disponible en RevenueCat');
        debugPrint('⚠️ Verifica en el dashboard de RevenueCat:');
        debugPrint('   1. Ve a Project Settings > Offerings');
        debugPrint(
          '   2. Asegúrate de que el offering "ofrng88de02fd2f" existe',
        );
        debugPrint('   3. O marca un offering como "Current"');
        debugPrint('   4. Agrega tus productos: rc_monthly y rc_annual');
        debugPrint(
          '   5. Asegúrate de que el entitlement "MyCarApp Pro" esté vinculado',
        );
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error al obtener paquetes disponibles: $e');
      debugPrint('Stack trace: $stackTrace');

      // Si es un error de configuración, proporcionar ayuda específica
      if (e.toString().contains('CONFIGURATION_ERROR') ||
          e.toString().contains('could not be fetched')) {
        debugPrint('');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('⚠️ ERROR DE CONFIGURACIÓN DE PRODUCTOS');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint(
          'RevenueCat no puede obtener los productos desde la tienda.',
        );
        debugPrint('');
        debugPrint('SOLUCIONES PARA DESARROLLO/PRUEBAS:');
        debugPrint('');
        if (Platform.isIOS) {
          debugPrint('📱 iOS - IMPORTANTE:');
          debugPrint(
            '   El archivo StoreKit SOLO funciona cuando ejecutas desde Xcode directamente.',
          );
          debugPrint(
            '   Si ejecutas con "flutter run", NO usará el archivo StoreKit.',
          );
          debugPrint('');
          debugPrint('   Para usar StoreKit Configuration:');
          debugPrint(
            '   1. Abre el proyecto en Xcode: open ios/Runner.xcworkspace',
          );
          debugPrint('   2. Ejecuta la app desde Xcode (⌘R), NO desde Flutter');
          debugPrint('   3. Verifica que el esquema tenga configurado:');
          debugPrint('      - Product > Scheme > Edit Scheme > Run > Options');
          debugPrint('      - StoreKit Configuration: testPursharse.storekit');
          debugPrint('');
          debugPrint('   Verifica que el archivo StoreKit tenga:');
          debugPrint('    - Product ID: rc_monthly (precio 4.99)');
          debugPrint('    - Product ID: rc_annual (precio 49.99)');
          debugPrint('');
          debugPrint(
            '   O configura productos en App Store Connect (requiere cuenta de desarrollador)',
          );
        } else if (Platform.isAndroid) {
          debugPrint('🤖 Android - CONFIGURACIÓN:');
          debugPrint('');
          debugPrint('1️⃣ GOOGLE PLAY CONSOLE:');
          debugPrint('   Ve a: https://play.google.com/console');
          debugPrint(
            '   Selecciona tu app > Monetización > Productos > Suscripciones',
          );
          debugPrint('   Crea estas suscripciones:');
          debugPrint('   ┌─────────────────────────────────────────────────┐');
          debugPrint('   │ Product ID: rc_monthly                        │');
          debugPrint('   │ Nombre: Plan Mensual                          │');
          debugPrint('   │ Precio: \$5.00 USD (o tu precio)               │');
          debugPrint('   │ Período: Mensual                              │');
          debugPrint('   └─────────────────────────────────────────────────┘');
          debugPrint('   ┌─────────────────────────────────────────────────┐');
          debugPrint('   │ Product ID: rc_annual                           │');
          debugPrint('   │ Nombre: Plan Anual                               │');
          debugPrint('   │ Precio: \$50.00 USD (o tu precio)                │');
          debugPrint('   │ Período: Anual                                   │');
          debugPrint('   └─────────────────────────────────────────────────┘');
          debugPrint('');
          debugPrint('2️⃣ REVENUECAT DASHBOARD:');
          debugPrint('   Configura los mismos productos en RevenueCat:');
          debugPrint('   - Product ID: rc_monthly (Store: Google Play)');
          debugPrint('   - Product ID: rc_annual (Store: Google Play)');
          debugPrint('   - Entitlement: MyCarApp Pro');
          debugPrint('   - Offering con paquetes para ambos productos');
          debugPrint('');
          debugPrint('3️⃣ MODO DE PRUEBA:');
          debugPrint(
            '   - Agrega tu cuenta de Gmail como tester en Play Console',
          );
          debugPrint('   - O usa productos de prueba internos');
          debugPrint(
            '   - La app debe estar publicada (al menos en modo interno)',
          );
          debugPrint('');
          debugPrint(
            '⚠️ IMPORTANTE: Los Product IDs deben coincidir EXACTAMENTE',
          );
          debugPrint('   entre Google Play Console y RevenueCat Dashboard');
        }
        debugPrint('');
        debugPrint(
          'VERIFICACIÓN EN REVENUECAT DASHBOARD (NO requiere cuenta de desarrollador):',
        );
        debugPrint('   1. Ve a https://app.revenuecat.com');
        debugPrint('   2. Selecciona tu proyecto');
        debugPrint('   3. Ve a "Products" y CREA/VERIFICA que existan:');
        debugPrint('      - Product ID: rc_monthly');
        debugPrint('        Tipo: Auto-renewable subscription');
        debugPrint(
          '        Store: App Store (aunque uses StoreKit, marca App Store)',
        );
        debugPrint('      - Product ID: rc_annual');
        debugPrint('        Tipo: Auto-renewable subscription');
        debugPrint('        Store: App Store');
        debugPrint('   4. Ve a "Entitlements" y CREA/VERIFICA:');
        debugPrint('      - Entitlement ID: MyCarApp Pro');
        debugPrint('      - Vincula los productos: rc_monthly y rc_annual');
        debugPrint('   5. Ve a "Offerings" y CREA/VERIFICA:');
        debugPrint('      - Offering ID: ofrng88de02fd2f (o crea uno nuevo)');
        debugPrint(
          '      - Marca como "Current" si quieres que sea el predeterminado',
        );
        debugPrint('      - Agrega paquetes:');
        debugPrint(
          '        * Package ID: \$rc_monthly (o monthly) -> Product: rc_monthly',
        );
        debugPrint(
          '        * Package ID: \$rc_annual (o annual) -> Product: rc_annual',
        );
        debugPrint('');
        debugPrint(
          '   IMPORTANTE: Los Product IDs deben coincidir EXACTAMENTE con StoreKit',
        );
        debugPrint('');
        debugPrint('Más información: https://rev.cat/why-are-offerings-empty');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');
      }

      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    _isLoading = true;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      await _updateSubscriptionTier(customerInfo);
      _isLoading = false;
      return true;
    } on PlatformException catch (e) {
      _isLoading = false;
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('⚠️ Compra cancelada por el usuario');
      } else {
        debugPrint('❌ Error al realizar compra: ${e.message}');
      }
      return false;
    } catch (e) {
      _isLoading = false;
      debugPrint('❌ Error inesperado al realizar compra: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    _isLoading = true;
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _updateSubscriptionTier(customerInfo);
      _isLoading = false;
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      _isLoading = false;
      debugPrint('❌ Error al restaurar compras: $e');
      return false;
    }
  }

  Future<void> checkSubscriptionStatus() async {
    await _loadSubscriptionStatus();
  }

  Future<void> identifyUser(String userId) async {
    try {
      await Purchases.logIn(userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
    } catch (e) {
      debugPrint('❌ Error al identificar usuario: $e');
    }
  }
}
