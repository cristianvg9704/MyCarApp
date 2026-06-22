import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/subscription_provider.dart';
import '../utils/my_car_colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Package? _selectedPackage;
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _checkIfFirstTime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false,
      );
      debugPrint('🔍 Inicializando SubscriptionProvider...');
      subscriptionProvider.initialize();
    });
  }

  Future<void> _checkIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenSubscription = prefs.getBool('has_seen_subscription') ?? false;
    setState(() {
      _isFirstTime = !hasSeenSubscription;
    });
  }

  Future<void> _markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_subscription', true);
  }

  Future<void> _handleContinue() async {
    await _markAsSeen();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _handlePurchase(Package package) async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    final success = await subscriptionProvider.purchasePackage(package);

    if (mounted) {
      if (success) {
        await _markAsSeen();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Suscripción activada exitosamente!'),
            backgroundColor: MyCarColors.success,
          ),
        );
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              subscriptionProvider.errorMessage ??
                  'Error al procesar la compra',
            ),
            backgroundColor: MyCarColors.error,
          ),
        );
      }
    }
  }

  String _getPackageDisplayName(Package package) {
    final identifier = package.identifier.toLowerCase();
    if (identifier.contains('monthly') ||
        identifier.contains('mensual') ||
        identifier.contains('rc_monthly')) {
      return 'Mensual';
    } else if (identifier.contains('yearly') ||
        identifier.contains('anual') ||
        identifier.contains('rc_annual')) {
      return 'Anual';
    }
    return package.storeProduct.title;
  }

  String _getPackagePrice(Package package) {
    return package.storeProduct.priceString;
  }

  String _getPackageDescription(Package package) {
    final identifier = package.identifier.toLowerCase();
    if (identifier.contains('monthly') ||
        identifier.contains('mensual') ||
        identifier.contains('rc_monthly')) {
      return '\$5 USD al mes';
    } else if (identifier.contains('yearly') ||
        identifier.contains('anual') ||
        identifier.contains('rc_annual')) {
      return '\$50 USD al año';
    }
    return package.storeProduct.description;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyCarColors.background,
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscriptionProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isFirstTime)
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => context.pop(),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Icono o logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: MyCarColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Título
                  Text(
                    _isFirstTime ? '¡Bienvenido a MyCar!' : 'Elige tu Plan',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MyCarColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isFirstTime
                        ? 'Desbloquea todas las funciones premium'
                        : 'Actualiza tu suscripción para acceder a todas las funciones',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: MyCarColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Opción Free
                  _buildPlanCard(
                    context,
                    title: 'Plan Gratuito',
                    price: 'Gratis',
                    description: 'Funciones básicas',
                    features: const [
                      'Hasta 3 vehículos',
                      'Alertas básicas',
                      'Soporte por email',
                    ],
                    isSelected: _selectedPackage == null,
                    isPremium: false,
                    onTap: () {
                      setState(() {
                        _selectedPackage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Opciones Premium
                  if (subscriptionProvider.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (subscriptionProvider.availablePackages.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: MyCarColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MyCarColors.warning.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: MyCarColors.warning,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Configuración Pendiente',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: MyCarColors.warning,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay paquetes disponibles. Para activar las suscripciones:',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: MyCarColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          _buildConfigStep(
                            context,
                            '1',
                            'Ve al dashboard de RevenueCat',
                          ),
                          _buildConfigStep(
                            context,
                            '2',
                            'Crea un Offering con identifier "default"',
                          ),
                          _buildConfigStep(
                            context,
                            '3',
                            'Agrega productos: monthly_subscription y yearly_subscription',
                          ),
                          _buildConfigStep(
                            context,
                            '4',
                            'Vincula el entitlement "MyCarApp Pro" a los productos',
                          ),
                          const SizedBox(height: 12),
                          if (subscriptionProvider.errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: MyCarColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: MyCarColors.error.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: MyCarColors.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Error de Configuración',
                                          style: TextStyle(
                                            color: MyCarColors.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    subscriptionProvider.errorMessage ??
                                        'Error desconocido',
                                    style: TextStyle(
                                      color: MyCarColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (subscriptionProvider.errorMessage
                                              ?.contains(
                                                'CONFIGURATION_ERROR',
                                              ) ==
                                          true ||
                                      subscriptionProvider.errorMessage
                                              ?.contains(
                                                'could not be fetched',
                                              ) ==
                                          true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Para desarrollo/pruebas:',
                                            style: TextStyle(
                                              color: MyCarColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'iOS: Crea un StoreKit Configuration File en Xcode con los productos monthly_subscription y yearly_subscription.',
                                            style: TextStyle(
                                              color: MyCarColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Android: Configura productos de prueba en Google Play Console o usa productos internos.',
                                            style: TextStyle(
                                              color: MyCarColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    ...subscriptionProvider.availablePackages.map((package) {
                      final isMonthly =
                          package.identifier.toLowerCase().contains(
                            'monthly',
                          ) ||
                          package.identifier.toLowerCase().contains(
                            'mensual',
                          ) ||
                          package.identifier.toLowerCase().contains(
                            'rc_monthly',
                          );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPlanCard(
                          context,
                          title: _getPackageDisplayName(package),
                          price: _getPackagePrice(package),
                          description: _getPackageDescription(package),
                          features: [
                            'Vehículos ilimitados',
                            'Alertas avanzadas',
                            'Notificaciones personalizadas',
                            'Soporte prioritario',
                            isMonthly
                                ? 'Renovación mensual'
                                : 'Ahorra 17% con plan anual',
                          ],
                          isSelected:
                              _selectedPackage?.identifier ==
                              package.identifier,
                          isPremium: true,
                          onTap: () {
                            setState(() {
                              _selectedPackage = package;
                            });
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 32),
                  // Botón de acción
                  if (_selectedPackage == null)
                    FilledButton(
                      onPressed: _handleContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: MyCarColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continuar con Plan Gratuito',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: subscriptionProvider.isLoading
                          ? null
                          : () => _handlePurchase(_selectedPackage!),
                      style: FilledButton.styleFrom(
                        backgroundColor: MyCarColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: subscriptionProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Suscribirse Ahora',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  const SizedBox(height: 16),
                  // Botón restaurar compras
                  TextButton(
                    onPressed: subscriptionProvider.isLoading
                        ? null
                        : () async {
                            final success = await subscriptionProvider
                                .restorePurchases();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Compras restauradas exitosamente'
                                        : 'No se encontraron compras para restaurar',
                                  ),
                                  backgroundColor: success
                                      ? MyCarColors.success
                                      : MyCarColors.warning,
                                ),
                              );
                              if (success) {
                                await _markAsSeen();
                                context.go('/');
                              }
                            }
                          },
                    child: const Text('Restaurar compras'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required String description,
    required List<String> features,
    required bool isSelected,
    required bool isPremium,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyCarColors.primary : MyCarColors.gray300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MyCarColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: MyCarColors.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: MyCarColors.primary,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: MyCarColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: MyCarColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: MyCarColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: MyCarColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MyCarColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigStep(BuildContext context, String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: MyCarColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: MyCarColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
