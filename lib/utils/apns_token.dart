/// Espera a que iOS entregue el token de APNs.
///
/// Tras pedir permiso, el sistema registra el dispositivo con APNs de forma
/// asíncrona; pedir el token de FCM o suscribirse a un topic antes de que llegue
/// lanza `apns-token-not-set`. Reintenta [attempts] veces cada [interval] y
/// devuelve null si nunca llega (simulador, falta la capability de Push
/// Notifications o el perfil de aprovisionamiento no la incluye).
Future<String?> waitForApnsToken(
  Future<String?> Function() getApnsToken, {
  int attempts = 10,
  Duration interval = const Duration(seconds: 1),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final token = await getApnsToken();
    if (token != null && token.isNotEmpty) return token;
    if (attempt < attempts - 1) await Future<void>.delayed(interval);
  }
  return null;
}
