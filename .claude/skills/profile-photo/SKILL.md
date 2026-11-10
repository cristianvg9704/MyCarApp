---
name: profile-photo
description: Foto de perfil del usuario (elegir en Perfil, guardarla en la app y mostrarla en Inicio y Perfil). Úsalo al tocar ProfileScreen, UserProvider.updatePhoto, UserAvatar o ProfilePhotoStorage.
---

# Foto de perfil

## Flujo
1. Ajustes → Perfil → tocar la foto → cámara o galería (`image_picker`).
2. `ProfilePhotoStorage.save` **copia** el archivo temporal del selector al directorio de documentos de la app
   (`profile_photo_<ms>.<ext>`) y borra la foto anterior si también era de la app.
3. `UserProvider.updatePhoto(ruta)` guarda la ruta en el estado y en `user_metadata.photo_path` de Supabase.
4. `UserProvider` notifica y **todas** las pantallas que usan `UserAvatar` se actualizan (Inicio y Perfil).

## Capas y archivos
| Capa | Archivo |
|---|---|
| UI reutilizable | `lib/widgets/user_avatar.dart`: `UserAvatar(photoPath, iconSize)`. Foto del usuario → imagen por defecto → icono |
| Almacenamiento | `lib/services/profile_photo_storage.dart`: `ProfilePhotoStorage` (directorio y reloj inyectables) |
| Estado | `lib/providers/user_provider.dart` |
| Pantallas | `ProfileScreen` (elige y guarda, `photoStorage` inyectable), `HomeScreen` (cabecera con `UserAvatar`) |

## Reglas
- Usa siempre `UserAvatar`; no vuelvas a poner `Image.asset('defaultUser.jpg')` fijo (era el bug: Inicio nunca mostraba
  la foto).
- La ruta del selector es temporal: **no se guarda tal cual**, siempre pasa por `ProfilePhotoStorage`.
- La foto no se sube a ningún servidor (solo la ruta en `user_metadata`); así lo dice la política de privacidad.
- Cualquier `UserProvider.update*` debe conservar `photoPath` (cambiar el correo la borraba).
- Limitación conocida: la ruta es absoluta. Si iOS cambia el contenedor de la app (reinstalación) la foto no se
  encuentra y se muestra la imagen por defecto.

## Tests
- `test/services/profile_photo_storage_test.dart`: copia, extensión, reemplazo, no borra archivos ajenos.
- `test/widgets/user_avatar_test.dart`: `UserAvatar` (defecto/archivo), Inicio refleja el cambio de foto, y el cambio
  de correo conserva la foto.
