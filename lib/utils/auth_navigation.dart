import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// A dónde ir tras iniciar sesión o crear la cuenta: la pantalla de suscripción
/// (siempre en dev, la primera vez en producción) y después el home.
Future<void> goAfterSignIn(BuildContext context) async {
  if (AppConfig.isDevMode) {
    context.go('/subscription');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  final hasSeenSubscription = prefs.getBool('has_seen_subscription') ?? false;
  context.go(hasSeenSubscription ? '/home' : '/subscription');
}
