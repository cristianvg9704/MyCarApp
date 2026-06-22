import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/alert.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _testMode = false; // Modo de prueba: programa notificaciones para unos segundos después (false = modo producción)
  Timer? _pendingNotificationsTimer; // Timer para consultar notificaciones pendientes cada 20 segundos

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Inicializar timezone
    tz.initializeTimeZones();
    
    // Establecer la zona horaria local explícitamente usando flutter_timezone
    try {
      // Obtener la zona horaria IANA del dispositivo (ej: "America/New_York", "Europe/Madrid")
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String tzName = timezoneInfo.identifier;
      debugPrint('Zona horaria del dispositivo: $tzName');
      
      // Establecer la zona horaria local explícitamente
      tz.setLocalLocation(tz.getLocation(tzName));
      
      debugPrint('Zona horaria local configurada: ${tz.local.name}');
    } catch (e) {
      debugPrint('⚠️ Advertencia al configurar zona horaria: $e');
      debugPrint('Usando zona horaria por defecto: ${tz.local.name}');
      // Si falla, tz.local debería seguir funcionando con la zona por defecto
    }

    // Configuración para Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    // No solicitar permisos aquí — se solicitan explícitamente en requestPermissions()
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    // Configuración inicial
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inicializar el plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('NotificationService inicializado');

    // Crear canal de notificaciones para Android (solo en Android)
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // Crear canal de notificaciones con alta importancia
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'alert_channel',
            'Alertas de Vehículos',
            description:
                'Notificaciones para recordatorios de mantenimiento y pagos',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
        debugPrint('Canal de notificaciones creado: alert_channel');
      }
    }

    _initialized = true;

    // Iniciar monitor de notificaciones pendientes (cada 20 segundos)
    startPendingNotificationsMonitor();
  }

  /// Verifica si ya se tienen permisos de notificaciones (sin solicitarlos)
  Future<bool> checkPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    if (Platform.isAndroid) {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        return await androidImpl.areNotificationsEnabled() ?? false;
      }
    }

    // En iOS no hay forma de verificar permisos sin solicitarlos;
    // asumimos true ya que se solicitan explícitamente en requestPermissions()
    return true;
  }

  /// Solicita permisos para notificaciones
  /// En Android 13+ solicita el permiso POST_NOTIFICATIONS
  /// En iOS solicita alert, badge y sound
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('Solicitando permisos de notificaciones...');

    if (Platform.isAndroid) {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        final bool? granted = await androidImpl.requestNotificationsPermission();
        debugPrint('Permisos Android: ${granted == true ? "concedidos" : "denegados"}');
        return granted ?? false;
      }
    }

    if (Platform.isIOS) {
      final iosImpl = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImpl != null) {
        final bool? granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('Permisos iOS: ${granted == true ? "concedidos" : "denegados"}');
        return granted ?? false;
      }
    }

    return true;
  }

  /// Maneja cuando el usuario toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificación tocada: ${response.payload}');
    // Aquí podrías navegar a la pantalla de alertas o a la alerta específica
    // usando el payload que contiene el ID de la alerta
  }

  /// Método de prueba: muestra una notificación inmediata
  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'alert_channel',
          'Alertas de Vehículos',
          channelDescription:
              'Notificaciones para recordatorios de mantenimiento y pagos',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999,
      'Prueba de Notificación',
      'Si ves esto, las notificaciones están funcionando correctamente',
      notificationDetails,
    );

    debugPrint('✅ Notificación de prueba mostrada');
  }

  /// Programa una notificación para una alerta
  Future<void> scheduleAlertNotification(Alert alert) async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('=== Programando notificación para alerta: ${alert.id} ===');
    debugPrint('Título: ${alert.title}');
    debugPrint('Fecha alerta: ${alert.alertDate}');
    debugPrint('Es recurrente: ${alert.isRecurring}');
    debugPrint('Tipo recurrencia: ${alert.recurrenceType}');
    debugPrint('Frecuencia: ${alert.recurrenceCount}');
    debugPrint('Modo prueba: $_testMode');

    // No programar notificaciones para alertas completadas o con fechas pasadas
    if (alert.isCompleted) {
      debugPrint('Alerta completada, no se programa notificación');
      return;
    }

    final now = DateTime.now();
    final alertDate = alert.alertDate;

    // Obtener hora de notificación (default 8:00 AM)
    final notificationTimeStr = alert.notificationTime ?? '08:00';
    final timeParts = notificationTimeStr.split(':');
    final notificationHour = int.parse(timeParts[0]);
    final notificationMinute = int.parse(timeParts[1]);
    debugPrint(
      'Hora de notificación: $notificationTimeStr ($notificationHour:$notificationMinute)',
    );
    debugPrint('Notificar días antes: ${alert.notifyDaysBefore}');

    // Normalizar la fecha de la alerta para comparar solo fechas (sin hora)
    final alertDateNormalized = DateTime(
      alertDate.year,
      alertDate.month,
      alertDate.day,
    );
    final todayNormalized = DateTime(now.year, now.month, now.day);

    // Determinar las fechas de las notificaciones
    // Si la alerta es recurrente y tiene frecuencia, programar múltiples notificaciones
    final List<DateTime> scheduledDates = [];

    if (_testMode) {
      // En modo de prueba, siempre programar al menos una notificación
      // No importa la fecha, se programará para unos segundos después
      debugPrint('MODO PRUEBA: Verificando condiciones de recurrencia...');
      debugPrint('  - isRecurring: ${alert.isRecurring}');
      debugPrint('  - recurrenceType: ${alert.recurrenceType}');
      debugPrint('  - recurrenceCount: ${alert.recurrenceCount}');

      // Guardar recurrenceCount en una variable local para evitar múltiples null checks
      final recurrenceCount = alert.recurrenceCount;
      
      if (alert.isRecurring &&
          alert.recurrenceType != null &&
          recurrenceCount != null &&
          recurrenceCount > 0) {
        debugPrint('MODO PRUEBA: Entrando en bloque de recurrencia');
        // Agregar fechas según la frecuencia (aunque sean pasadas, en modo prueba se ajustarán)
        DateTime currentDate = alertDateNormalized;
        int count = 0;
        int maxCount = recurrenceCount;

        debugPrint('MODO PRUEBA: maxCount = $maxCount');

        while (count < maxCount) {
          debugPrint('MODO PRUEBA: Agregando fecha $count: $currentDate');
          scheduledDates.add(currentDate);
          count++;

          // Calcular la próxima fecha según el tipo de recurrencia
          if (alert.recurrenceType == 'daily') {
            currentDate = currentDate.add(const Duration(days: 1));
          } else if (alert.recurrenceType == 'weekly') {
            final interval = alert.recurrenceValue ?? 1;
            currentDate = currentDate.add(Duration(days: 7 * interval));
          } else if (alert.recurrenceType == 'monthly') {
            final interval = alert.recurrenceValue ?? 1;
            currentDate = DateTime(
              currentDate.year,
              currentDate.month + interval,
              currentDate.day,
            );
          } else if (alert.recurrenceType == 'custom_days') {
            final interval = alert.recurrenceValue ?? 1;
            currentDate = currentDate.add(Duration(days: interval));
          } else {
            debugPrint(
              'MODO PRUEBA: Tipo de recurrencia desconocido, saliendo del loop',
            );
            break;
          }
        }
        debugPrint(
          'MODO PRUEBA: Después del loop, scheduledDates.length = ${scheduledDates.length}',
        );
      } else {
        debugPrint(
          'MODO PRUEBA: No es recurrente o condiciones no cumplidas, agregando fecha única',
        );
        // Si no es recurrente, solo una notificación
        scheduledDates.add(alertDateNormalized);
        debugPrint('MODO PRUEBA: Agregada fecha única: $alertDateNormalized');
      }
      debugPrint(
        'MODO PRUEBA: Total de fechas programadas: ${scheduledDates.length}',
      );
    } else {
      // Modo normal: verificar que la fecha no haya pasado
      if (alertDateNormalized.compareTo(todayNormalized) < 0) {
        debugPrint(
          'La fecha de la alerta ya pasó, no se programa notificación',
        );
        return;
      }

      // Modo normal: solo fechas futuras
      // Guardar recurrenceCount en una variable local para evitar múltiples null checks
      final recurrenceCountNormal = alert.recurrenceCount;
      
      if (alert.isRecurring &&
          alert.recurrenceType != null &&
          recurrenceCountNormal != null &&
          recurrenceCountNormal > 0) {
        // Calcular las fechas según el tipo de recurrencia y el intervalo
        DateTime currentDate = alertDateNormalized;
        int count = 0;
        int maxCount = recurrenceCountNormal;

        while (count < maxCount) {
          // Si es hoy o futuro, agregar a la lista
          if (currentDate.compareTo(todayNormalized) >= 0) {
            scheduledDates.add(currentDate);
            count++;
          }

          // Calcular la próxima fecha según el tipo de recurrencia
          if (alert.recurrenceType == 'daily') {
            currentDate = currentDate.add(const Duration(days: 1));
          } else if (alert.recurrenceType == 'weekly') {
            final interval = alert.recurrenceValue ?? 1;
            currentDate = currentDate.add(Duration(days: 7 * interval));
          } else if (alert.recurrenceType == 'monthly') {
            final interval = alert.recurrenceValue ?? 1;
            currentDate = DateTime(
              currentDate.year,
              currentDate.month + interval,
              currentDate.day,
            );
          } else if (alert.recurrenceType == 'custom_days') {
            final interval = alert.recurrenceValue ?? 1;
            currentDate = currentDate.add(Duration(days: interval));
          } else {
            // Si no hay tipo válido, solo una notificación
            break;
          }
        }
      } else {
        // Si no es recurrente o no tiene frecuencia, solo una notificación para el día seleccionado
        if (alertDateNormalized.compareTo(todayNormalized) >= 0) {
          scheduledDates.add(alertDateNormalized);
        }
      }

      // Filtrar fechas pasadas y asegurar que todas sean futuras (solo en modo normal)
      scheduledDates.removeWhere((date) {
        final dateWithTime = DateTime(
          date.year,
          date.month,
          date.day,
          notificationHour,
          notificationMinute,
        );
        return dateWithTime.isBefore(now) || dateWithTime.isAtSameMomentAs(now);
      });
    }

    // Expandir con notificaciones de "días antes" si está configurado
    final List<DateTime> allDates = [];
    final List<bool> isEarlyReminderList = [];

    for (final date in scheduledDates) {
      // Agregar notificación de "días antes" si está configurado
      if (alert.notifyDaysBefore != null && alert.notifyDaysBefore! > 0) {
        final earlyDate = date.subtract(
          Duration(days: alert.notifyDaysBefore!),
        );
        if (_testMode) {
          // En modo prueba, siempre agregar
          allDates.add(earlyDate);
          isEarlyReminderList.add(true);
          debugPrint(
            'DÍAS ANTES: Agregada fecha anticipada (prueba): $earlyDate para fecha base: $date',
          );
        } else {
          // En modo normal, solo agregar si la fecha con hora es futura
          final earlyDateWithTime = DateTime(
            earlyDate.year,
            earlyDate.month,
            earlyDate.day,
            notificationHour,
            notificationMinute,
          );
          if (earlyDateWithTime.isAfter(now)) {
            allDates.add(earlyDate);
            isEarlyReminderList.add(true);
            debugPrint(
              'DÍAS ANTES: Agregada fecha anticipada: $earlyDate para fecha base: $date',
            );
          } else {
            debugPrint(
              'DÍAS ANTES: Fecha anticipada ya pasó: $earlyDate (omitida)',
            );
          }
        }
      }
      // Agregar fecha principal
      allDates.add(date);
      isEarlyReminderList.add(false);
    }

    debugPrint(
      'Total de notificaciones a programar (incluyendo días antes): ${allDates.length}',
    );

    // Si no hay fechas válidas, no programar nada
    if (allDates.isEmpty) {
      debugPrint('No hay fechas válidas para programar notificaciones');
      return;
    }

    // Configuración para Android
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'alert_channel',
          'Alertas de Vehículos',
          channelDescription:
              'Notificaciones para recordatorios de mantenimiento y pagos',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    // Configuración para iOS
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Detalles de la notificación
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Crear el título y cuerpo de la notificación
    final title = alert.title;
    final body = alert.description ?? 'Recordatorio de mantenimiento';

    // Base ID para las notificaciones
    final baseNotificationId =
        alert.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    // Programar notificaciones para cada fecha (incluyendo recordatorios anticipados)
    // CORRECCIÓN: Usar allDates en lugar de scheduledDates para incluir "días antes"
    debugPrint(
      '  [DEBUG] Iniciando loop para programar ${allDates.length} notificaciones',
    );
    for (int i = 0; i < allDates.length; i++) {
      try {
        debugPrint('  [DEBUG] Iteración ${i + 1}/${allDates.length}');
        final date = allDates[i];
        final isEarlyReminder = isEarlyReminderList[i];
        debugPrint(
          '  [DEBUG] Fecha base: $date, isEarlyReminder: $isEarlyReminder',
        );

        // Obtener la fecha/hora actual en la zona horaria local
        debugPrint('  [DEBUG] Obteniendo fecha/hora actual...');
        final nowTz = tz.TZDateTime.now(tz.local);
        debugPrint('  [DEBUG] Fecha/hora actual: $nowTz');
        debugPrint('  [DEBUG] Después de obtener nowTz, continuando...');

        tz.TZDateTime scheduledDate;
        debugPrint('  [DEBUG] Declarada variable scheduledDate');
        debugPrint('  [DEBUG] Modo prueba: $_testMode');
        debugPrint(
          '  [DEBUG] notificationHour: $notificationHour, notificationMinute: $notificationMinute',
        );
        debugPrint(
          '  [DEBUG] Entrando en bloque if/else para calcular scheduledDate...',
        );

        if (_testMode) {
          debugPrint('  [DEBUG] Entró en modo PRUEBA');
          // Modo de prueba: programar para (i + 1) * 5 segundos después de ahora
          // Primera notificación: 5 segundos, segunda: 10 segundos, tercera: 15 segundos, etc.
          final secondsDelay = (i + 1) * 5;
          // Asegurar que siempre sea al menos 2 segundos en el futuro para evitar problemas de timing
          final minDelay = secondsDelay < 2 ? 2 : secondsDelay;
          scheduledDate = nowTz.add(Duration(seconds: minDelay));
          debugPrint(
            'MODO PRUEBA: Notificación ${i + 1} programada para ${minDelay} segundos después de ahora',
          );
          debugPrint('  Hora local ahora: ${nowTz.toString()}');
          debugPrint('  Hora local programada: ${scheduledDate.toString()}');
        } else {
          debugPrint('  [DEBUG] Entró en modo NORMAL');
          // Modo normal: programar para la hora especificada en notificationHour:notificationMinute
          // CORRECCIÓN: Usar notificationHour y notificationMinute en lugar de siempre 00:00
          debugPrint(
            '  [DEBUG] Creando DateTime con: año=${date.year}, mes=${date.month}, día=${date.day}, hora=$notificationHour, minuto=$notificationMinute',
          );
          DateTime scheduledDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            notificationHour,
            notificationMinute,
          );
          debugPrint('  [DEBUG] scheduledDateTime creado: $scheduledDateTime');

          // Convertir la fecha programada a la zona horaria local primero
          debugPrint('  [DEBUG] Convirtiendo a TZDateTime...');
          scheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
          debugPrint('  [DEBUG] scheduledDate convertido: $scheduledDate');

          // Si la fecha es hoy o pasada, ajustar para mañana a la hora especificada
          if (scheduledDate.isBefore(nowTz) ||
              scheduledDate.isAtSameMomentAs(nowTz)) {
            // Programar para mañana a la hora especificada (notificationHour:notificationMinute) en la zona horaria local
            scheduledDate = tz.TZDateTime(
              tz.local,
              nowTz.year,
              nowTz.month,
              nowTz.day,
              notificationHour,
              notificationMinute,
            ).add(const Duration(days: 1));
            debugPrint(
              'Fecha ajustada al futuro: $scheduledDate (era: $scheduledDateTime)',
            );
          }

          // Verificación final: asegurar que la fecha sea futura (recalcular nowTz para asegurar precisión)
          debugPrint('  [DEBUG] Verificando si la fecha es futura...');
          final nowTzFinal = tz.TZDateTime.now(tz.local);
          debugPrint(
            '  [DEBUG] scheduledDate: $scheduledDate, nowTzFinal: $nowTzFinal',
          );
          if (scheduledDate.isBefore(nowTzFinal) ||
              scheduledDate.isAtSameMomentAs(nowTzFinal)) {
            debugPrint(
              '⚠️ Saltando notificación ${i + 1}: fecha aún en el pasado o presente después del ajuste ($scheduledDate, ahora: $nowTzFinal)',
            );
            continue;
          }
          debugPrint('  [DEBUG] Fecha es futura, continuando...');
        }

        // Usar el ID base + índice como ID de notificación para evitar conflictos
        debugPrint('  [DEBUG] Calculando notificationId...');
        final notificationId = baseNotificationId + i;
        debugPrint(
          '  [DEBUG] Calculado notificationId: $notificationId (base: $baseNotificationId, índice: $i)',
        );

        try {
          debugPrint(
            'Intentando programar notificación ${i + 1}/${allDates.length}',
          );
          if (isEarlyReminder) {
            debugPrint(
              '  Tipo: Recordatorio anticipado (${alert.notifyDaysBefore} días antes)',
            );
          } else {
            debugPrint('  Tipo: Notificación principal');
          }
          debugPrint('  ID: $notificationId');
          debugPrint('  Título: $title');
          debugPrint('  Cuerpo: $body');
          debugPrint('  [DEBUG] Antes de mostrar fecha programada...');
          debugPrint('  Fecha programada: $scheduledDate');
          debugPrint('  [DEBUG] Después de mostrar fecha programada...');
          final nowForDiff = tz.TZDateTime.now(tz.local);
          debugPrint('  Fecha actual: $nowForDiff');
          debugPrint('  [DEBUG] Calculando diferencia...');
          final diff = scheduledDate.difference(nowForDiff);
          debugPrint(
            '  Diferencia: ${diff.inSeconds} segundos (${diff.inMinutes} minutos)',
          );
          debugPrint('  Continuando con verificación de permisos...');

          // Usar alarmClock para mayor confiabilidad (se ejecuta incluso en modo Doze)
          // Esta es la diferencia clave: alarmClock tiene mayor prioridad que exactAllowWhileIdle
          AndroidScheduleMode scheduleMode = AndroidScheduleMode.alarmClock;
          debugPrint(
            '  Usando modo: alarmClock (mayor prioridad, funciona incluso en modo Doze)',
          );

          // Verificar que la fecha sea realmente futura antes de programar
          final nowBeforeSchedule = tz.TZDateTime.now(tz.local);
          if (scheduledDate.isBefore(nowBeforeSchedule) ||
              scheduledDate.isAtSameMomentAs(nowBeforeSchedule)) {
            debugPrint(
              '⚠️ ADVERTENCIA: La fecha programada ($scheduledDate) es anterior o igual a ahora ($nowBeforeSchedule). Ajustando...',
            );
            scheduledDate = nowBeforeSchedule.add(const Duration(seconds: 2));
            debugPrint('Nueva fecha ajustada: $scheduledDate');
          }

          // Programar la notificación
          try {
            debugPrint('  [DEBUG] Llamando a zonedSchedule...');
            debugPrint('  [DEBUG] Parámetros:');
            debugPrint('    - notificationId: $notificationId');
            debugPrint('    - title: $title');
            debugPrint('    - body: $body');
            debugPrint('    - scheduledDate: $scheduledDate');
            debugPrint('    - scheduleMode: $scheduleMode');
            debugPrint('    - payload: ${alert.id}');

            // Programar la notificación
            // En Android usa alarmClock, en iOS no se especifica androidScheduleMode
            await _notifications.zonedSchedule(
              notificationId,
              title,
              body,
              scheduledDate,
              notificationDetails,
              androidScheduleMode: scheduleMode, // Solo aplica en Android
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: alert.id, // Pasar el ID de la alerta como payload
            );

            debugPrint('  [DEBUG] zonedSchedule completado sin errores');

            debugPrint(
              '✅ Notificación ${i + 1}/${allDates.length} programada exitosamente',
            );
            debugPrint('   ID: $notificationId');
            debugPrint('   Modo: alarmClock (alta prioridad)');
            debugPrint(
              '   Programada para: $scheduledDate (${scheduledDate.timeZoneName})',
            );
            final finalNow = tz.TZDateTime.now(tz.local);
            debugPrint('   Ahora es: $finalNow (${finalNow.timeZoneName})');
            final finalDiff = scheduledDate.difference(finalNow);
            debugPrint(
              '   Diferencia final: ${finalDiff.inHours}h ${finalDiff.inMinutes % 60}m ${finalDiff.inSeconds % 60}s',
            );
            debugPrint('   Diferencia en segundos: ${finalDiff.inSeconds}');
          } catch (scheduleError) {
            debugPrint('❌ ERROR al programar notificación: $scheduleError');
            debugPrint('   Stack trace: ${StackTrace.current}');
            rethrow;
          }

          // Verificar que la notificación se programó correctamente consultando las notificaciones pendientes
          try {
            final List<PendingNotificationRequest> pendingNotifications =
                await _notifications.pendingNotificationRequests();
            final matchingNotifications = pendingNotifications
                .where((n) => n.id == notificationId)
                .toList();
            if (matchingNotifications.isNotEmpty) {
              debugPrint(
                '✅ Verificación: La notificación está en la lista de pendientes (ID: ${matchingNotifications.first.id})',
              );
            } else {
              debugPrint(
                '⚠️ ADVERTENCIA: La notificación NO está en la lista de pendientes',
              );
              debugPrint(
                '   Total de notificaciones pendientes: ${pendingNotifications.length}',
              );
              if (pendingNotifications.isNotEmpty) {
                debugPrint(
                  '   IDs de notificaciones pendientes: ${pendingNotifications.map((n) => n.id).join(", ")}',
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ No se pudo verificar notificaciones pendientes: $e');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ ERROR CRÍTICO programando notificación ${i + 1}: $e');
          debugPrint('   Tipo de error: ${e.runtimeType}');
          debugPrint('   Mensaje: ${e.toString()}');
          debugPrint('   Stack trace completo:');
          debugPrint('   $stackTrace');
          // Continuar con las siguientes notificaciones aunque una falle
        }
      } catch (outerError, outerStackTrace) {
        debugPrint(
          '❌ ERROR CRÍTICO en el loop externo (iteración ${i + 1}): $outerError',
        );
        debugPrint('   Tipo de error: ${outerError.runtimeType}');
        debugPrint('   Mensaje: ${outerError.toString()}');
        debugPrint('   Stack trace: $outerStackTrace');
        // Continuar con la siguiente iteración
      }
    }
    debugPrint(
      '  [DEBUG] Loop de programación completado. Total procesadas: ${allDates.length}',
    );
  }

  /// Actualiza una notificación existente
  Future<void> updateAlertNotification(Alert alert) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancelar todas las notificaciones anteriores de esta alerta
    final baseNotificationId =
        alert.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    // Cancelar hasta 100 notificaciones posibles (por si acaso)
    for (int i = 0; i < 100; i++) {
      await _notifications.cancel(baseNotificationId + i);
    }

    // Si la alerta no está completada y la fecha es futura, programar nuevas notificaciones
    if (!alert.isCompleted) {
      final alertDateNormalized = DateTime(
        alert.alertDate.year,
        alert.alertDate.month,
        alert.alertDate.day,
      );
      final todayNormalized = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      if (alertDateNormalized.compareTo(todayNormalized) >= 0) {
        await scheduleAlertNotification(alert);
      }
    }
  }

  /// Cancela todas las notificaciones de una alerta
  Future<void> cancelNotification(Alert alert) async {
    if (!_initialized) {
      await initialize();
    }

    final baseNotificationId =
        alert.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    // Cancelar hasta 100 notificaciones posibles (por si acaso)
    for (int i = 0; i < 100; i++) {
      await _notifications.cancel(baseNotificationId + i);
    }
    debugPrint('Notificaciones canceladas para alerta: ${alert.id}');
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAllNotifications() async {
    if (!_initialized) {
      await initialize();
    }

    await _notifications.cancelAll();
    debugPrint('Todas las notificaciones canceladas');
  }

  /// Programa notificaciones para todas las alertas pendientes
  Future<void> scheduleAllPendingAlerts(List<Alert> alerts) async {
    if (!_initialized) {
      await initialize();
    }

    for (final alert in alerts) {
      if (!alert.isCompleted && alert.alertDate.isAfter(DateTime.now())) {
        try {
          await scheduleAlertNotification(alert);
        } catch (e) {
          debugPrint(
            'Error programando notificación para alerta ${alert.id}: $e',
          );
        }
      }
    }
  }

  /// Verifica el estado de las notificaciones y muestra información de depuración
  Future<void> checkNotificationStatus() async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('=== Estado de Notificaciones ===');
    debugPrint('Inicializado: $_initialized');
    debugPrint('Modo prueba: $_testMode');

    final AndroidFlutterLocalNotificationsPlugin? androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      final bool? hasPermission = await androidImpl.areNotificationsEnabled();
      debugPrint('Permisos de notificación concedidos: $hasPermission');

      final bool? canScheduleExact = await androidImpl
          .canScheduleExactNotifications();
      debugPrint('Puede programar exactas: $canScheduleExact');
    } else {
      debugPrint('No es Android');
    }
    debugPrint('================================');
  }

  /// Verifica si una notificación específica aún está pendiente (no ejecutada)
  /// Retorna true si la notificación está pendiente, false si ya se ejecutó o no existe
  Future<bool> isNotificationPending(int notificationId) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final List<PendingNotificationRequest> pendingNotifications =
          await _notifications.pendingNotificationRequests();

      final isPending = pendingNotifications.any((n) => n.id == notificationId);
      debugPrint('Notificación ID $notificationId está pendiente: $isPending');
      return isPending;
    } catch (e) {
      debugPrint('Error verificando notificación pendiente: $e');
      return false;
    }
  }

  /// Verifica si una alerta tiene notificaciones pendientes
  /// Retorna true si hay al menos una notificación pendiente para esta alerta
  Future<bool> hasPendingNotificationsForAlert(Alert alert) async {
    if (!_initialized) {
      await initialize();
    }

    if (alert.id == null) {
      return false;
    }

    try {
      final List<PendingNotificationRequest> pendingNotifications =
          await _notifications.pendingNotificationRequests();

      // El ID base de las notificaciones se calcula como alert.id.hashCode
      final baseNotificationId = alert.id!.hashCode;

      // Buscar cualquier notificación que coincida con el ID base
      // (las notificaciones usan baseNotificationId + índice)
      final hasPending = pendingNotifications.any((n) {
        // Las notificaciones pueden tener IDs desde baseNotificationId hasta baseNotificationId + 100
        return n.id >= baseNotificationId && n.id < baseNotificationId + 100;
      });

      debugPrint(
        'Alerta ${alert.id} tiene notificaciones pendientes: $hasPending',
      );
      return hasPending;
    } catch (e) {
      debugPrint('Error verificando notificaciones pendientes para alerta: $e');
      return false;
    }
  }

  /// Obtiene todas las notificaciones pendientes del sistema
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error obteniendo notificaciones pendientes: $e');
      return [];
    }
  }

  /// Inicia un timer que consulta cada 20 segundos si las notificaciones están pendientes
  /// y muestra logs con el estado y la hora de ejecución
  void startPendingNotificationsMonitor() {
    // Cancelar timer existente si hay uno
    stopPendingNotificationsMonitor();

    debugPrint(
      '🔄 Iniciando monitor de notificaciones pendientes (cada 20 segundos)',
    );

    _pendingNotificationsTimer = Timer.periodic(const Duration(seconds: 20), (
      timer,
    ) async {
      await _checkAndLogPendingNotifications();
    });

    // Ejecutar inmediatamente la primera vez
    _checkAndLogPendingNotifications();
  }

  /// Detiene el monitor de notificaciones pendientes
  void stopPendingNotificationsMonitor() {
    if (_pendingNotificationsTimer != null) {
      _pendingNotificationsTimer!.cancel();
      _pendingNotificationsTimer = null;
      debugPrint('⏹️ Monitor de notificaciones pendientes detenido');
    }
  }

  /// Consulta y muestra logs de todas las notificaciones pendientes
  Future<void> _checkAndLogPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final now = DateTime.now();
      final pendingNotifications = await _notifications
          .pendingNotificationRequests();

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint(
        '📋 CONSULTA DE NOTIFICACIONES PENDIENTES - ${_formatDateTime(now)}',
      );
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint(
        'Total de notificaciones pendientes: ${pendingNotifications.length}',
      );
      debugPrint('');

      if (pendingNotifications.isEmpty) {
        debugPrint('⚠️ No hay notificaciones pendientes en este momento');
      } else {
        for (final notification in pendingNotifications) {
          // Si está en la lista de pendientes, está pendiente
          const String status = '✅ PENDIENTE';

          // Nota: PendingNotificationRequest no incluye la fecha programada directamente
          // La fecha está programada en el sistema operativo pero no es accesible desde aquí
          // Podríamos obtenerla del payload (alert.id) y buscar la alerta en la BD si es necesario

          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('ID: ${notification.id}');
          debugPrint('Estado: $status');
          debugPrint('Título: ${notification.title ?? "Sin título"}');
          debugPrint('Cuerpo: ${notification.body ?? "Sin cuerpo"}');
          debugPrint(
            'Payload (Alert ID): ${notification.payload ?? "Sin payload"}',
          );
          debugPrint('Hora de consulta: ${_formatDateTime(now)}');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Próxima consulta en 20 segundos...');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error consultando notificaciones pendientes: $e');
    }
  }

  /// Formatea una fecha/hora para mostrar en logs
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
