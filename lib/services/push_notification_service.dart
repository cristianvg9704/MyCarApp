import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../utils/apns_token.dart';
import 'notification_service.dart';

/// Topic al que se suscriben todos los dispositivos para recibir
/// anuncios generales (novedades, noticias, eventos) enviados por el
/// equipo de desarrollo desde la consola de Firebase o un backend propio.
///
/// Al ser un topic (en vez de tokens individuales), enviar un anuncio a
/// cualquier cantidad de usuarios es una sola llamada a la API de FCM:
/// Firebase se encarga del fan-out, sin necesidad de un backend propio
/// para el broadcast en sí.
const String kNewsTopic = 'app_news';

/// Maneja mensajes de Firebase Cloud Messaging que llegan con la app en
/// segundo plano o terminada.
///
/// Debe ser una función de nivel superior (no un método de instancia): el
/// sistema operativo la ejecuta en un isolate separado, sin acceso al
/// estado de la app en memoria.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No hay UI que actualizar aquí: en background/terminada, FCM ya muestra
  // la notificación del sistema automáticamente a partir del payload
  // "notification" del mensaje (a diferencia de foreground, que si requiere
  // mostrarla manualmente - ver PushNotificationService._onForegroundMessage).
  debugPrint('📩 Mensaje FCM recibido en background: ${message.messageId}');
}

/// Notificaciones push disparadas desde el servidor (Firebase Cloud
/// Messaging) - para anuncios de novedades/noticias/eventos.
///
/// Distinto de [NotificationService]: ese sirve para recordatorios
/// programados localmente en el dispositivo (mantenimientos, alertas);
/// este sirve para mensajes que el equipo de desarrollo decide enviar en
/// un momento arbitrario, a todos los usuarios.
///
/// Requiere que el proyecto tenga configurado Firebase (google-services.json
/// en android/app/, GoogleService-Info.plist en ios/Runner/, y una APNs Auth
/// Key subida en la consola de Firebase para iOS). Sin esa configuración,
/// [initialize] falla de forma controlada y el resto de la app sigue
/// funcionando con normalidad (mismo patrón que la inicialización de
/// Supabase/RevenueCat en main.dart).
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  static PushNotificationService get instance => _instance;

  PushNotificationService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      'Permisos de push (FCM): ${settings.authorizationStatus}',
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

    // Si el token se renueva (o llega tarde), se completa el registro
    messaging.onTokenRefresh.listen((_) => _registerDevice(messaging));

    // En iOS el token de APNs llega de forma asíncrona tras pedir permiso:
    // sin esperarlo, getToken/subscribeToTopic lanzan `apns-token-not-set`.
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // No se espera aquí: APNs puede tardar (o no llegar en un simulador) y
      // no debe retrasar el arranque de la app.
      unawaited(_registerWhenApnsReady(messaging));
      return;
    }

    await _registerDevice(messaging);
  }

  /// Espera hasta ~1 minuto a que iOS entregue el token de APNs y entonces
  /// registra el dispositivo.
  Future<void> _registerWhenApnsReady(FirebaseMessaging messaging) async {
    final apnsToken = await waitForApnsToken(
      messaging.getAPNSToken,
      attempts: 60,
    );
    if (apnsToken == null) {
      debugPrint(
        '⚠️ iOS no entregó el token de APNs en 60 s. Simulador: es lo normal. '
        'iPhone real: revisa la red (APNs usa el puerto 5223, VPN/Wi-Fi '
        'corporativo pueden bloquearlo), prueba con datos móviles y '
        'reinstala la app.',
      );
      return;
    }
    debugPrint('🍏 Token de APNs recibido');
    await _registerDevice(messaging);
  }

  /// Suscribe el dispositivo al topic de novedades y muestra su token de FCM.
  /// No lanza: si falla (p. ej. sin APNs todavía) se reintenta con
  /// `onTokenRefresh`.
  Future<void> _registerDevice(FirebaseMessaging messaging) async {
    try {
      await messaging.subscribeToTopic(kNewsTopic);
      debugPrint('Suscrito al topic de novedades: $kNewsTopic');

      // Solo para depuración/pruebas: permite copiar el token y pegarlo en
      // Firebase Console > Cloud Messaging > "Send test message" para probar
      // un envío dirigido a este dispositivo específico (distinto del topic,
      // que envía a todos los suscritos).
      final fcmToken = await messaging.getToken();
      debugPrint('🔑 FCM registration token de este dispositivo:');
      debugPrint(fcmToken);
    } catch (e) {
      debugPrint('⚠️ No se pudo registrar el dispositivo en FCM todavía: $e');
    }
  }

  /// FCM no muestra el banner del sistema automáticamente en Android
  /// cuando la app está en primer plano - hay que mostrarlo a mano.
  /// En iOS, el propio SO sí puede mostrarlo si se configura
  /// `setForegroundNotificationPresentationOptions`, pero se reutiliza el
  /// mismo camino aquí para tener un único estilo de notificación en toda
  /// la app (incluye la de bienvenida, alertas de mantenimiento, y estas).
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await NotificationService.instance.showRemoteNotification(
      title: notification.title ?? 'MyCar',
      body: notification.body ?? '',
      payload: message.data['id']?.toString(),
    );
  }

  /// Se dispara cuando el usuario toca la notificación y esta abre la app
  /// desde segundo plano (no desde terminada - ese caso se maneja con
  /// `FirebaseMessaging.instance.getInitialMessage()` si se necesita más
  /// adelante, ej. para navegar a una pantalla específica del anuncio).
  void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint(
      '👆 Usuario abrió la app desde una notificación push: ${message.messageId}',
    );
    // TODO: navegar a una pantalla de detalle del anuncio si el payload
    // (message.data) trae esa información.
  }
}
