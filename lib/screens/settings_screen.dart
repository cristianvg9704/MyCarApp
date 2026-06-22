import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';
import '../utils/my_car_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'Español';

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Idioma'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Español'),
                leading: Radio<String>(
                  value: 'Español',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('English'),
                leading: Radio<String>(
                  value: 'English',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: MyCarColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          'Configuración',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Apariencia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: MyCarColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<AppProvider>(
            builder: (context, appProvider, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: MyCarColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          appProvider.themeMode == ThemeMode.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: MyCarColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modo Oscuro',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: MyCarColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appProvider.themeMode == ThemeMode.dark
                                  ? 'Activado'
                                  : appProvider.themeMode == ThemeMode.light
                                  ? 'Desactivado'
                                  : 'Seguir sistema',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: MyCarColors.textSecondary,
                                    fontSize: 13,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: appProvider.themeMode == ThemeMode.dark,
                        onChanged: (value) {
                          appProvider.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                        activeColor: MyCarColors.primary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'General',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: MyCarColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          _buildSettingCard(
            context,
            icon: Icons.language,
            title: 'Idioma',
            subtitle: _selectedLanguage,
            colorScheme: colorScheme,
            onTap: _showLanguageDialog,
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            colorScheme: colorScheme,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'MyCar',
                applicationVersion: '1.0.0',
                applicationIcon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: MyCarColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white),
                ),
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Una aplicación moderna para gestionar tus vehículos y sus ingresos.',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Suscripción',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: MyCarColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<SubscriptionProvider>(
            builder: (context, subscriptionProvider, child) {
              String subscriptionStatus = 'Plan Gratuito';

              if (subscriptionProvider.isPremium) {
                if (subscriptionProvider.currentTier ==
                    SubscriptionTier.monthly) {
                  subscriptionStatus = 'Plan Mensual - \$5 USD/mes';
                } else if (subscriptionProvider.currentTier ==
                    SubscriptionTier.yearly) {
                  subscriptionStatus = 'Plan Anual - \$50 USD/año';
                }
              }

              return _buildSettingCard(
                context,
                icon: subscriptionProvider.isPremium
                    ? Icons.star
                    : Icons.star_border,
                title: 'Estado de Suscripción',
                subtitle: subscriptionStatus,
                colorScheme: colorScheme,
                iconColor: subscriptionProvider.isPremium
                    ? MyCarColors.primary
                    : null,
                onTap: () {
                  context.push('/subscription');
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Consumer<SubscriptionProvider>(
            builder: (context, subscriptionProvider, child) {
              return _buildSettingCard(
                context,
                icon: Icons.restore,
                title: 'Restaurar Compras',
                subtitle: 'Restaurar tus compras anteriores',
                colorScheme: colorScheme,
                onTap: () {
                  if (!subscriptionProvider.isLoading) {
                    subscriptionProvider.restorePurchases().then((success) {
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
                      }
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Cuenta',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: MyCarColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.person,
            title: 'Perfil',
            subtitle: 'Ver y editar tu perfil',
            colorScheme: colorScheme,
            onTap: () {
              context.push('/profile');
            },
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.logout,
            title: 'Cerrar sesión',
            subtitle: 'Salir de tu cuenta',
            colorScheme: colorScheme,
            iconColor: MyCarColors.error,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                    '¿Estás seguro de que quieres cerrar sesión?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: MyCarColors.error,
                      ),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                await authProvider.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconColor != null
                        ? iconColor.withOpacity(0.1)
                        : MyCarColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? MyCarColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: MyCarColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MyCarColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: MyCarColors.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
