import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/subscription_provider.dart';
import '../utils/account_actions.dart';
import '../utils/my_car_colors.dart';
import '../utils/subscription_plans.dart';
import '../utils/my_car_palette.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  /// Plan que el usuario tocó. Mientras sea null se marca el plan que ya tiene.
  String? _chosenPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false,
      );
      debugPrint('🔍 Inicializando SubscriptionProvider...');
      subscriptionProvider.initialize();
    });
  }

  Future<void> _handlePurchase(Package package) async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    final success = await subscriptionProvider.purchasePackage(package);

    if (mounted) {
      if (success) {
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

  String _actionLabel(PlanAction action, Package? selected) {
    switch (action) {
      case PlanAction.subscribe:
        return 'Suscribirse Ahora';
      case PlanAction.switchPlan:
        if (selected != null && isYearlyPackage(selected)) {
          return 'Cambiar a plan Anual';
        }
        if (selected != null && isMonthlyPackage(selected)) {
          return 'Cambiar a plan Mensual';
        }
        return 'Cambiar de plan';
      case PlanAction.manage:
        return 'Administrar suscripción';
    }
  }

  Future<void> _handleManage(SubscriptionProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await provider.openManageSubscription();
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir la administración de la suscripción. '
            'Hazlo desde los ajustes de tu cuenta de Apple o Google.',
          ),
          backgroundColor: MyCarColors.warning,
        ),
      );
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

  /// Texto bajo el precio. El precio y la moneda salen de la tienda
  /// (`priceString`); aquí solo se explica la renovación automática.
  String _getPackageDescription(Package package) {
    if (isMonthlyPackage(package)) {
      return 'Se renueva cada mes hasta que la canceles';
    }
    if (isYearlyPackage(package)) {
      return 'Se renueva cada año hasta que la canceles';
    }
    return package.storeProduct.description;
  }

  @override
  Widget build(BuildContext context) {
    // Sin plan no se puede salir de esta pantalla (ni con "atrás" en Android).
    final canLeave = context.watch<SubscriptionProvider>().isPremium;
    return PopScope(
      canPop: canLeave,
      child: Scaffold(
        backgroundColor: context.palette.background,
        body: SafeArea(
          child: Consumer<SubscriptionProvider>(
            builder: (context, subscriptionProvider, child) {
              final packages = subscriptionProvider.availablePackages;
              final tier = subscriptionProvider.currentTier;
              final currentId = currentPlanId(tier, packages);
              final selectedId = selectedPlanId(
                tier: tier,
                packages: packages,
                chosen: _chosenPlanId,
              );
              final action = actionFor(
                tier: tier,
                packages: packages,
                selectedId: selectedId,
              );
              Package? selectedPackage;
              for (final package in packages) {
                if (package.identifier == selectedId) selectedPackage = package;
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (subscriptionProvider.isPremium)
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
                      subscriptionProvider.isPremium
                          ? 'Tu plan'
                          : 'Elige tu plan',
                      key: const Key('subscription_title'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.palette.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subscriptionProvider.isPremium
                          ? 'Cambia de plan o administra tu suscripción'
                          : 'Suscríbete para usar MyCar. Cancela cuando quieras.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Planes disponibles
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
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
                                  ?.copyWith(
                                    color: context.palette.textPrimary,
                                  ),
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
                                                color:
                                                    context.palette.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'iOS: Crea un StoreKit Configuration File en Xcode con los productos monthly_subscription y yearly_subscription.',
                                              style: TextStyle(
                                                color: context
                                                    .palette
                                                    .textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Android: Configura productos de prueba en Google Play Console o usa productos internos.',
                                              style: TextStyle(
                                                color: context
                                                    .palette
                                                    .textSecondary,
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
                      ...packages.map((package) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildPlanCard(
                            context,
                            title: _getPackageDisplayName(package),
                            price: _getPackagePrice(package),
                            description: _getPackageDescription(package),
                            features: planFeatures(package),
                            isSelected: selectedId == package.identifier,
                            isCurrent: currentId == package.identifier,
                            isPremium: true,
                            onTap: () {
                              setState(() {
                                _chosenPlanId = package.identifier;
                              });
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                    // Botón de acción: depende del plan actual y del elegido
                    FilledButton(
                      key: const Key('subscription_primary_button'),
                      onPressed: subscriptionProvider.isLoading
                          ? null
                          : () => switch (action) {
                              PlanAction.manage => _handleManage(
                                subscriptionProvider,
                              ),
                              PlanAction.subscribe || PlanAction.switchPlan =>
                                selectedPackage == null
                                    ? null
                                    : _handlePurchase(selectedPackage),
                            },
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
                          : Text(
                              _actionLabel(action, selectedPackage),
                              style: const TextStyle(
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
                                  context.go('/');
                                }
                              }
                            },
                      child: const Text('Restaurar compras'),
                    ),
                    // Sin plan la pantalla es obligatoria: estas dos salidas
                    // siguen disponibles (Apple exige poder eliminar la cuenta
                    // desde la app).
                    if (!subscriptionProvider.isPremium) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('subscription_sign_out'),
                        onPressed: () => signOutAndGoToLogin(context),
                        child: const Text('Cerrar sesión'),
                      ),
                      TextButton(
                        key: const Key('subscription_delete_account'),
                        onPressed: () => confirmAndDeleteAccount(context),
                        style: TextButton.styleFrom(
                          foregroundColor: MyCarColors.error,
                        ),
                        child: const Text('Eliminar mi cuenta'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
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
    bool isCurrent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.palette.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MyCarColors.primary : context.palette.border,
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
                if (isCurrent)
                  Container(
                    key: const Key('subscription_current_badge'),
                    margin: EdgeInsets.only(left: isPremium ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MyCarColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PLAN ACTUAL',
                      style: TextStyle(
                        color: MyCarColors.success,
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
                    color: context.palette.accent,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.palette.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.palette.textSecondary,
              ),
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
                          color: context.palette.textPrimary,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
