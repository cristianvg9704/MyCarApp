---
name: voice-transactions
description: Registro de ingresos y egresos por voz (reconocimiento del dispositivo + parser local en español). Úsalo al tocar el botón de voz, SpeechRecognizer, el parser de frases, los permisos de micrófono o al integrar IA para interpretar el audio.
---

# Registro por voz

El usuario dice una frase ("gasté cincuenta mil en gasolina ayer") y la app la interpreta como un movimiento.
No se guarda nada automáticamente: el usuario revisa lo entendido y pulsa **Guardar** (la voz puede equivocarse).
**Sin IA ni red propia**: voz a texto con el motor nativo del dispositivo y un parser por reglas. Integrar un LLM queda
pendiente (ver al final).

## Flujo
1. **Micrófono del vehículo** (con el vehículo ya elegido):
   - Detalle del vehículo → icono de micrófono en el AppBar (`CarDetailScreen`).
   - Finanzas → icono de micrófono en la tarjeta de cada vehículo (`FinancesListScreen`).
   Ambos abren `TransactionModalHelper.showVoiceTransactionSheet(context, carId:)`: una **hoja compacta**
   (`VoiceTransactionSheet`) que **no muestra el formulario de ingresos/egresos**. Solo muestra el micrófono, el texto que
   se va entendiendo y, al terminar, el resumen de lo interpretado (tipo, monto, descripción, categoría, fecha, litros, km)
   con **Guardar** y **Hablar de nuevo**. Empieza a escuchar al abrirse. Sin monto no se puede guardar.
2. **Formulario completo** (`AddTransactionScreen`, botón + de Finanzas/detalle): conserva su botón **Registrar por voz**;
   ahí la voz rellena el formulario, el vehículo se elige en el selector y el usuario pulsa Guardar.
3. `SpeechRecognizer` entrega resultados parciales (transcripción en vivo) y uno final.
4. `VoiceTransactionParser.parse` convierte el texto en un `VoiceTransactionDraft`. Sin verbo ni categoría el tipo por
   defecto en la hoja es **egreso** (en el formulario, el tipo que esté elegido).

## El micrófono nunca queda activo
- Tocar el micrófono mientras escucha sale de "escuchando" **de inmediato** (`processing`) y luego interpreta.
- Guardar apaga el micrófono antes de escribir (`VoiceCaptureController.release()` en la hoja; en el formulario se
  cancela el reconocedor si seguía escuchando). `release()` conserva lo interpretado por si el guardado falla.
- Cerrar la hoja o la pantalla (`dispose`) cancela el reconocedor; los eventos tardíos de una escucha cancelada se ignoran.

## Capas
| Capa | Archivo |
|---|---|
| Reconocimiento | `lib/services/speech_recognizer.dart`: `SpeechRecognizer` (abstracta), `DeviceSpeechRecognizer` (paquete `speech_to_text`), `SpeechFailure` |
| Parser de frases | `lib/services/voice_transaction_parser.dart` (`VoiceTransactionParser`, `VoiceTransactionDraft`) |
| Números en español | `lib/utils/spanish_number_parser.dart` (`tokenizeSpanish`, `extractSpokenNumbers`, `normalizeSpanish`) |
| Estado de la captura | `lib/providers/voice_capture_controller.dart`: `VoiceCaptureController` (idle → listening → processing → ready / noSpeech / error), `canSave`, `release()`, `cancel()`. Lógica pura con reconocedor y reloj inyectables |
| Hoja de voz | `lib/widgets/voice_transaction_sheet.dart`: `VoiceTransactionSheet`; se abre con `TransactionModalHelper.showVoiceTransactionSheet` |
| Borrador → movimiento | `VoiceTransactionDraft.toTransaction(userId:, carId:)` (litros solo en combustible, km solo en combustible/mantenimiento) |
| Formulario | `AddTransactionScreen` (`speechRecognizer` y `startWithVoice` inyectables) |

## Reglas del parser (español de Colombia)
- **Tipo:** verbos fuertes de egreso (gasté, pagué, compré, tanqueé, eché…) o de ingreso (me pagaron, ingreso, cobré, gané,
  recibí, vendí, hice, carrera…). Si aparecen ambos gana el primero. Sin verbos, una palabra de categoría implica egreso; si no, se usa el
  tipo actual del formulario.
- **Categoría (solo egresos):** combustible (gasolina, tanqueo, acpm, gas, litros, galones), mantenimiento (aceite, mecánico,
  taller, llantas, frenos, filtro, revisión…), otros (peaje, parqueadero, lavado, multa, soat…). Sin palabra clave: otros
  (o combustible si hay litros). Primera palabra que aparece gana.
- **Monto:** números con dígitos (`50.000`, `$50.000`, `80 mil`, `1,5 millones`), con palabras (`ciento veinte mil`) o
  jerga (`80 lucas`). Se excluyen los números ya usados como litros, galones, km o fecha, y el artículo "un/una".
  Si hay varios, prefiere el marcado con `$` o "pesos"; si no, el mayor.
- **Litros / galones:** `10 litros`; los galones se convierten (1 gal = 3,785 L, 2 decimales).
- **Kilometraje:** `45200 km`, `45 mil kilómetros`, `kilometraje 45200`. Solo se conserva en combustible y mantenimiento.
- **Millones:** después de "millón/millones", un grupo de 100 a 999 sin "mil" se entiende como miles ("un millón doscientos" = 1.200.000).
- **Vehículo:** `VoiceVehicle(id, brand, model)` + `parse(vehicles:)`; `mentionedCarId` es el vehículo con más palabras de marca/modelo
  en la frase ("el Mazda", "la Duster"); empate o ninguno → null (se usa el vehículo actual).
- **Ediciones:** `VoiceTransactionDraft.withType/withAmount/withCategory/withDate` (la pantalla de revisión edita el borrador).
- **Fecha:** hoy (por defecto), ayer, anteayer / antier / antes de ayer, `hace N días/semanas`, día de la semana (la
  ocurrencia pasada más reciente), `el 15 de octubre` (si queda en el futuro, año anterior).
- **Descripción:** combustible/mantenimiento → nombre de la categoría; el resto → la frase con mayúscula inicial.
- Todo lo de `VoiceTransactionParser` es puro (`now` inyectable).

## Permisos y plataforma
- Paquete `speech_to_text` (`pubspec.yaml`). Idioma: prefiere `es_CO`, luego cualquier `es_*`.
- iOS `Info.plist`: `NSMicrophoneUsageDescription` y `NSSpeechRecognitionUsageDescription`. Tras agregar el plugin hay que
  correr `cd ios && pod install`.
- Android `AndroidManifest.xml`: `RECORD_AUDIO`, `INTERNET`, `BLUETOOTH*` y `<queries>` para `android.speech.RecognitionService`.
  (`INTERNET` faltaba en el manifest principal; sin él los builds release no tenían red.)
- Errores: permiso negado, motor no disponible y fallo durante la escucha muestran un mensaje en español; "no match" y
  timeout de silencio se ignoran.

## Tests
- `test/utils/spanish_number_parser_test.dart` y `test/services/voice_transaction_parser_test.dart`: frases y casos límite.
- `test/helpers/fake_speech_recognizer.dart`: reconocedor falso compartido (`say`, `fail`, `finishWithoutFinalResult`).
- `test/providers/voice_capture_controller_test.dart`: estados, parciales, final tardío, `stop`, `release`, `cancel`, eventos
  tardíos, permisos y `dispose`.
- `test/widgets/voice_transaction_sheet_test.dart`: la hoja no muestra el formulario, transcripción en vivo, resumen, guardar
  (apaga el micrófono y cierra), sin monto, reintentar, permisos, cerrar y fallo al guardar.
- `test/widgets/add_transaction_screen_test.dart` (grupo `voice input`): escucha, transcripción parcial, llenado del
  formulario, guardado tras confirmar, permisos, errores, `startWithVoice`, cancelación al salir y guardar mientras escucha.
- `test/services/voice_transaction_parser_test.dart`: incluye `toTransaction`.
- `test/widgets/car_detail_screen_test.dart`: el AppBar ofrece la acción de voz.
- No se prueba `DeviceSpeechRecognizer` ni que los iconos de micrófono abran la hoja (crearía el motor nativo): verificar a
  mano en un dispositivo real.

## Pendiente
- Interpretar el texto con un LLM (por ejemplo Claude vía una Edge Function de Supabase, nunca con la API key en la app)
  usando `VoiceTransactionParser` como respaldo sin conexión. La salida debe seguir siendo un `VoiceTransactionDraft`.
- Asociar el vehículo por voz ("en el Corolla") cuando se registra desde Finanzas sin vehículo elegido.
- Soportar otras monedas e inglés.
