---
name: app-icon
description: Icono de la app en iOS y Android (generado desde assets/icons con flutter_launcher_icons). Úsalo al cambiar el icono, el color de fondo del icono adaptativo o regenerar los iconos nativos.
---

# Icono de la app

## Qué hace
Un solo origen de imágenes en `assets/icons/` genera todos los tamaños nativos:
- `mcIcon.png` (1024×1024, **sin transparencia**, fondo indigo `#4F46E5` + coche blanco): icono de iOS y icono clásico de Android (< 8).
- `foreground.png` (1024×1024, transparente, solo el coche): capa frontal del icono **adaptativo** de Android 8+.
  El fondo adaptativo es el color `#4F46E5` (= `MyCarColors.primary`, `android/.../values/colors.xml`).

## Archivos
- `flutter_launcher_icons.yaml` (configuración) y `flutter_launcher_icons` en `dev_dependencies`.
- Generados (se versionan): `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`, `android/app/src/main/res/mipmap-*/ic_launcher.png`,
  `drawable-*/ic_launcher_foreground.png`, `mipmap-anydpi-v26/ic_launcher.xml`, `values/colors.xml`.

## Cómo regenerar
1. Reemplaza las imágenes de `assets/icons/` (mismos nombres y tamaño).
2. `dart run flutter_launcher_icons`.
3. **Revisa y revierte** lo que la herramienta toca de más:
   - `ios/Runner.xcodeproj/project.pbxproj`: cambia `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`
     por `AppIcon` (error de la herramienta): `git checkout` ese archivo.
   - `AppIcon.appiconset/Contents.json` se reescribe y añade iconos obsoletos (50/57/72 px): restaurarlo con `git checkout`
     y borrar esos PNG sobrantes.

## Reglas
- iOS rechaza iconos con canal alfa: `remove_alpha_ios: true` y `mcIcon.png` sin transparencia.
- `adaptive_icon_foreground_inset: 0`: el foreground ya trae su margen (el coche ocupa ~46% del lienzo, dentro de la zona
  segura de 66%). Con el valor por defecto (16) el coche se vería demasiado pequeño.
- Un icono nuevo solo se ve tras reinstalar la app (iOS cachea el icono; a veces hay que borrarla antes).

## Cómo se prueba
No hay tests (son imágenes). Verificado con `xcrun actool` sobre `ios/Runner/Assets.xcassets` y `flutter build apk --debug`;
visualmente: reinstalar en el iPhone/Android y ver el icono en la pantalla de inicio.
