---
name: legal-policies
description: Política de Privacidad y Términos de Uso de la app (para App Store/Google Play y la app). Úsalo al cambiar qué datos se recopilan, añadir un SDK o proveedor, tocar permisos del dispositivo, la suscripción o el borrado de cuenta, o al publicar los documentos.
---

# Política de privacidad y términos de uso

## Qué es
Documentos para los usuarios finales, en español: `docs/legal/politica-de-privacidad.md` y `docs/legal/terminos-de-uso.md`.
Apple exige una **URL pública** de la política (App Store Connect) y que ambos enlaces sean accesibles dentro de la app
(obligatorio además por vender suscripciones, guideline 3.1.2 y 5.1.1).

## Pendiente antes de publicar
- Reemplazar los marcadores `[NOMBRE…]`, `[CORREO DE CONTACTO]`, `[PAÍS]`, `[CIUDAD / JURISDICCIÓN]`.
- Revisión legal del texto (no es asesoría jurídica) y adaptación a la ley local de protección de datos.
- Alojarlos en una URL pública (p. ej. GitHub Pages) y enlazarlos en App Store Connect y en la app (Ajustes y pantalla de suscripción).

## Debe coincidir con la realidad (revisar al cambiar el código)
- Datos recopilados = campos de los modelos y tablas de Supabase (`cars`, `car_transactions`, `mileage_readings`, `trip_logs`,
  `alerts`, `maintenance_logs`) + metadata de usuario (nombre, teléfono).
- **GPS**: las coordenadas se procesan en el dispositivo y no se envían; solo se guardan distancia, duración y horas
  (`TripLog`). Si se empiezan a guardar coordenadas o rutas, hay que cambiar política y etiqueta de privacidad de Apple.
- Foto del vehículo se sube (`imageBase64`); la de perfil solo guarda la ruta local.
- Voz: la procesa el reconocimiento del sistema; la app no recibe audio.
- Proveedores: Supabase, RevenueCat, Firebase Cloud Messaging, Apple, Google. Un SDK nuevo (analítica, anuncios, Crashlytics)
  obliga a actualizar política y etiquetas de privacidad.
- Borrado de cuenta: `delete_my_account` (skill `account-deletion`). Eliminar la cuenta no cancela la suscripción.
- Suscripción: renovación automática, cancelación 24 h antes y gestión en la tienda (skill `subscriptions`).

## Etiquetas de privacidad de Apple (App Store Connect)
Todos "App Functionality", vinculados al usuario, sin rastreo: Name, Email, Phone, Photos or Videos, Other User Content,
Other Financial Info, Purchase History, User ID, Device ID y Other Data Types. Sin Location, Audio, Diagnostics ni Usage Data.
