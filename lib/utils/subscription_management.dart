import 'package:flutter/foundation.dart';

/// Pantalla oficial de suscripciones de la App Store (iOS).
const String appStoreSubscriptionsUrl =
    'https://apps.apple.com/account/subscriptions';

/// Pantalla oficial de suscripciones de Google Play (Android).
const String playStoreSubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions';

/// URL donde el usuario administra o cancela su suscripción.
///
/// Las tiendas no permiten cancelar desde dentro de la app: solo se puede abrir
/// su pantalla de suscripciones. Si RevenueCat ya entregó una URL específica
/// ([managementUrl], viene en `CustomerInfo.managementURL`) se usa esa; si no,
/// se usa la pantalla general de la tienda de la plataforma. Devuelve `null`
/// donde no hay suscripciones por tienda (web, escritorio).
String? subscriptionManagementUrl({
  String? managementUrl,
  required TargetPlatform platform,
}) {
  if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
    return null;
  }
  if (managementUrl != null && managementUrl.trim().isNotEmpty) {
    return managementUrl.trim();
  }
  return platform == TargetPlatform.iOS
      ? appStoreSubscriptionsUrl
      : playStoreSubscriptionsUrl;
}
