import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A dónde ir tras iniciar sesión o crear la cuenta: al inicio. Si el usuario
/// no tiene una suscripción activa, el router (ver `subscriptionGateRedirect`)
/// lo manda a la pantalla de planes; no hay plan gratuito.
void goAfterSignIn(BuildContext context) => context.go('/home');
