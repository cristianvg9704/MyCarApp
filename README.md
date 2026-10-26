# MyCar

App Flutter para llevar el control de tus vehículos: ingresos y egresos (combustible, mantenimiento),
kilometraje y viajes con GPS, alertas y recomendaciones de mantenimiento. Backend en Supabase.

## Requisitos

| Herramienta | Para qué | Versión |
|---|---|---|
| Flutter (stable) | todo | Dart SDK `^3.8.1` (ver `pubspec.yaml`) |
| Android Studio o Android SDK | Android | JDK 17 (viene con Android Studio) |
| Xcode + CocoaPods | iOS (solo macOS) | iOS mínimo 15.0 |
| VS Code con extensión Dart/Flutter, o Android Studio | editor | opcional |

Verifica tu entorno con:
```bash
flutter doctor
```
Resuelve lo que marque en rojo para la plataforma que vayas a usar.

## Preparación (una sola vez)

```bash
git clone <url-del-repo>
cd NewMyCarApp
flutter pub get
cd ios && pod install && cd ..     # solo si vas a correr en iOS
```

### Base de datos (Supabase)

La app usa Supabase (URL y clave pública en `lib/config/supabase_config.dart`). Si usas un proyecto
nuevo, ejecuta estos SQL en el **SQL Editor**, en orden:

1. Tablas base `cars` e `incomes` con sus políticas RLS: [docs/RLS_TENANT_ARCHITECTURE.md](docs/RLS_TENANT_ARCHITECTURE.md).
   (La tabla de alertas no está documentada en `docs/`; se crea aparte.)
2. [docs/SUPABASE_MILEAGE_MIGRATION.md](docs/SUPABASE_MILEAGE_MIGRATION.md): kilometraje, mantenimientos y viajes.
3. [docs/SUPABASE_TRANSACTIONS_MIGRATION.md](docs/SUPABASE_TRANSACTIONS_MIGRATION.md): ingresos y egresos
   (renombra `incomes` a `car_transactions`). **Sin esta migración las pantallas de Finanzas fallan.**

## Ejecutar en Android

### Emulador
1. En Android Studio: **Device Manager → Create Device** y arráncalo (o `flutter emulators --launch <id>`).
2. Corre la app:
   ```bash
   flutter devices          # confirma que aparece el emulador
   flutter run -d <id>
   ```

### Teléfono físico
1. En el teléfono: **Ajustes → Acerca del teléfono** y toca 7 veces "Número de compilación".
2. **Opciones de desarrollador → Depuración por USB** activada.
3. Conéctalo por cable, acepta la huella RSA y verifica:
   ```bash
   flutter devices
   flutter run -d <id>
   ```

Package de la app: `com.cris.new_my_car_app`.

### Instalar una versión permanente (release)
```bash
flutter run --release -d <id>          # compila, instala y abre
# o solo generar el APK:
flutter build apk --release            # build/app/outputs/flutter-apk/app-release.apk
```

## Ejecutar en iOS (requiere macOS)

### Simulador
```bash
open -a Simulator
flutter run -d "iPhone 17 Pro"     # o el id que muestre `flutter devices`
```
Atajo del [makefile](makefile): `make simulator`.

### iPhone físico
1. Conecta el iPhone por cable, desbloquéalo y toca **Confiar en este equipo**.
2. Activa **Ajustes → Privacidad y seguridad → Modo desarrollador** y reinicia el teléfono.
3. Verifica que Flutter lo ve y ejecuta:
   ```bash
   flutter devices
   flutter run -d <id-del-iphone>
   ```
   Atajo: `make iphone` (solo funciona si el teléfono se llama `iPhone`).
4. La primera vez, si iOS dice "Desarrollador no confiable": **Ajustes → General → VPN y administración
   de dispositivos →** tu cuenta → **Confiar**.

La firma es automática con el bundle `com.cris.newMyCarApp`. Si falla, abre `ios/Runner.xcworkspace` en Xcode
→ target **Runner** → **Signing & Capabilities** y elige tu equipo.

### Instalar una versión permanente (release)

Una build **debug** de iOS solo abre con el depurador conectado: al cerrar la terminal el icono queda pero la app
no arranca. Para dejarla instalada usa release:
```bash
flutter run --release -d <id-del-iphone>
```
Con una cuenta de Apple gratuita la app caduca a los 7 días y hay que reinstalarla; con la cuenta de pago dura un año.

## Comandos útiles

```bash
flutter run                # modo debug con hot reload (r = reload, R = restart, q = salir)
flutter run --profile      # medir rendimiento
flutter clean && flutter pub get   # si algo queda en mal estado
flutter analyze            # análisis estático
```

## Tests

```bash
flutter test                                   # toda la suite
flutter test test/utils                        # una carpeta
flutter test test/utils/currency_formatter_test.dart
flutter test --plain-name "parseAmount"        # por nombre
```
En VS Code hay tareas en `.vscode/tasks.json` (**Tasks: Run Task → Test: …**) y la vista Testing de la extensión Dart.

## Solución de problemas

| Problema | Qué hacer |
|---|---|
| `flutter devices` no lista el teléfono | cable de datos (no solo carga), desbloquear, aceptar "Confiar"/huella RSA, `flutter doctor` |
| iOS: error de CocoaPods | `cd ios && pod repo update && pod install && cd ..` |
| iOS: aviso de Swift Package Manager | es solo una advertencia de plugins sin soporte SPM; no impide compilar |
| iOS: app instalada no abre | era build debug; reinstala con `--release` |
| Las pantallas de Finanzas dan error | falta ejecutar la migración de transacciones en Supabase |
| `No se pudieron cargar tus vehículos` | sin internet, sesión expirada o proyecto Supabase pausado (plan gratuito) |

## Servicios que requieren configuración

- **Notificaciones push (Firebase):** iOS usa `ios/Runner/GoogleService-Info.plist`. En Android falta
  `android/app/google-services.json` y aplicar el plugin de Google Services; mientras tanto la inicialización de FCM
  falla de forma controlada y el resto de la app funciona.
- **Suscripciones (RevenueCat):** la clave configurada en `lib/services/subscription_service.dart` es la de iOS
  (`appl_…`). Para compras en Android hace falta la clave de Google Play de RevenueCat.
- **Ubicación y viajes GPS:** la app pide permisos de ubicación (en segundo plano para registrar viajes);
  acéptalos en el primer uso.

## Documentación del proyecto

- `docs/` — arquitectura, RLS y migraciones de Supabase.
- `.claude/skills/` — documentación por feature (qué hace, capas, reglas y tests). Se mantiene al día con cada cambio.
- `CLAUDE.md` — reglas de trabajo del proyecto.
