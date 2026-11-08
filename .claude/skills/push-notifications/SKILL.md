---
name: push-notifications
description: Notificaciones push de servidor con Firebase Cloud Messaging (anuncios por topic o por token) y su registro en APNs en iOS. Úsalo al tocar PushNotificationService, el registro de APNs en AppDelegate, el topic app_news, google-services/GoogleService-Info o las capabilities de push.
---

# Notificaciones push (FCM)

## Qué hace
Permite enviar anuncios (novedades, eventos) desde la consola de Firebase a todos los
dispositivos (topic `app_news`) o a uno concreto (token de FCM). Es distinto de las
notificaciones **locales** (`NotificationService`: alertas de mantenimiento, bienvenida).

## Archivos y capas
- `lib/services/push_notification_service.dart`: `PushNotificationService` (singleton).
  `initialize()` pide permiso, registra listeners (`onMessage`, `onMessageOpenedApp`,
  `onTokenRefresh`) y registra el dispositivo. El handler de background es una función de
  nivel superior (`firebaseMessagingBackgroundHandler`), requisito de FCM.
- `lib/utils/apns_token.dart`: `waitForApnsToken` (función pura, testeable) que sondea el token
  de APNs con reintentos.
- `lib/services/notification_service.dart`: `showRemoteNotification` dibuja el banner cuando el
  mensaje llega con la app en primer plano.
- `lib/main.dart`: llama a `PushNotificationService.instance.initialize()` dentro de try/catch;
  si Firebase no está configurado, la app sigue funcionando.
- `ios/Runner/AppDelegate.swift`: llama a `registerForRemoteNotifications()` al arrancar y
  registra en consola si APNs entregó el token o por qué falló.
- `ios/Runner/Runner.entitlements`: `aps-environment`.
- `ios/Runner/Info.plist`: `UIBackgroundModes` con `remote-notification`.

## Reglas de negocio
- Todos los dispositivos se suscriben al topic `kNewsTopic = 'app_news'`.
- En iOS el token de FCM no existe hasta que APNs entrega su token: nunca llamar a
  `getToken`/`subscribeToTopic` antes. Por eso `_registerWhenApnsReady` espera hasta ~60 s
  **en segundo plano** (no bloquea el arranque).
- Simulador de iOS: APNs no entrega token; el aviso `⚠️ iOS no entregó el token de APNs` es
  esperado y no es un error. Probar push siempre en un iPhone real.
- `GoogleService-Info.plist` contiene la clave de API de Firebase y por ahora no se versiona.
  `project.pbxproj` lo referencia como recurso: en un clon limpio hay que descargarlo de
  Firebase → Project settings → tu app iOS y copiarlo a `ios/Runner/`, o el build de iOS falla.

## Configuración fuera del código
1. Apple Developer: App ID `com.cris.newMyCarApp` con Push Notifications habilitado.
2. Clave APNs (`.p8`) subida en Firebase → Project settings → Cloud Messaging (Key ID y Team ID).
3. Xcode: capabilities Push Notifications y Background Modes → Remote notifications.
4. Android: falta `android/app/google-services.json` y el plugin de Google Services.

## Cómo se prueba
- Unitario: `flutter test test/utils/apns_token_test.dart`.
- Manual (iPhone real, build debug para ver el log): `flutter run -d <iphone>`; esperar
  `🍏 Token de APNs recibido`, `Suscrito al topic…` y `🔑 FCM registration token`.
  Firebase → Messaging → *Send test message* con ese token, o campaña al topic `app_news`.
  Con la app en segundo plano el sistema muestra el banner; en primer plano lo dibuja
  `showRemoteNotification`.
- Una build release no muestra logs: para obtener el token usar debug.
