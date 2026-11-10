---
name: voice-transactions
description: Registro de ingresos y egresos por voz (reconocimiento del dispositivo + parser local en español). Úsalo al tocar el botón de voz, SpeechRecognizer, el parser de frases, los permisos de micrófono o al integrar IA para interpretar el audio.
---

# Registro por voz

El usuario dice una frase ("gasté cincuenta mil en gasolina ayer") y la app la interpreta como un movimiento.
No se guarda nada automáticamente: el usuario revisa lo entendido y pulsa **Guardar** (la voz puede equivocarse).
**Sin IA ni red propia**: voz a texto con el motor nativo del dispositivo y un parser por reglas. Integrar un LLM queda
pendiente (ver al final).

## Flujo: hoja `VoiceEntrySheet` (3 pasos)
Entradas con el vehículo ya elegido: micrófono en el AppBar del detalle (`CarDetailScreen`) y en la tarjeta de cada
vehículo de Finanzas (`FinancesListScreen`). Ambas llaman a
`TransactionModalHelper.showVoiceTransactionSheet(context, carId:, onChanged:)`, que abre la hoja (fondo blanco, radio
superior 28, velo `MyCarColors.scrim`). **No muestra el formulario de ingresos/egresos.**

1. **Listo** (`idle`): título, chip del vehículo (toca → selector), micrófono de 104 px en un halo de 156 px,
   "Toca el micrófono y habla" y la sección "Prueba decir" con 3 ejemplos. No escucha hasta que se toca el micrófono.
2. **Escuchando** (`listening` / `processing`): punto + "Escuchando…" + cronómetro `m:ss` + X (cancela y vuelve a Listo sin
   guardar), caja "Lo que entendí" con la transcripción parcial en vivo, onda de 32 barras (volumen del micrófono), y el
   micrófono con cuadrado de detener y dos halos que laten. Termina al tocar el botón o tras ~2 s de silencio
   (`pauseFor`). Vibración ligera al empezar y al terminar. Sin voz → "No te escuché bien" + "Intentar de nuevo".
3. **Revisa y guarda** (`ready`): frase original, control **Ingreso | Gasto**, monto de 44 px (`−$60.000` rojo / `+$150.000`
   verde; toca para editarlo), filas editables **Categoría** (solo gasto), **Vehículo** y **Fecha** (cada una abre su
   selector), litros/km si se dijeron, y los botones **Grabar de nuevo** y **Guardar gasto/ingreso** (solo se habilita con
   monto > 0 y un vehículo). Al guardar cierra la hoja, muestra "Gasto guardado" con **Deshacer** (borra el movimiento por
   su id) y refresca la pantalla de origen (`onChanged`, también al deshacer).
- **Errores** (`error` / `noSpeech`), dentro de la hoja: sin permiso explica para qué se usa el micrófono y ofrece
  **Abrir Ajustes** (`permission_handler.openAppSettings`); sin conexión (`SpeechFailure.network`) ofrece reintentar;
  sin reconocimiento disponible solo queda **Registrar a mano**. **Registrar a mano** cierra la hoja con
  `VoiceEntryManual` y el helper abre el formulario completo (`showAddTransactionModal`).

El formulario completo (`AddTransactionScreen`, botón + de Finanzas) conserva su botón **Registrar por voz**: ahí la voz solo
rellena el formulario y el usuario pulsa Guardar.

## El micrófono nunca queda activo
- Tocar el micrófono mientras escucha sale de "escuchando" **de inmediato** (`processing`) y luego interpreta.
- Guardar apaga el micrófono antes de escribir (`VoiceCaptureController.release()` en la hoja; en el formulario se cancela el
  reconocedor si seguía escuchando). `release()` conserva lo interpretado por si el guardado falla y hay que reintentar.
- Cerrar la hoja o la pantalla (`dispose`) cancela el reconocedor; los eventos tardíos de una escucha cancelada se ignoran.

## Capas
| Capa | Archivo |
|---|---|
| Reconocimiento | `lib/services/speech_recognizer.dart`: `SpeechRecognizer` (abstracta; `onSoundLevel` normalizado 0..1), `DeviceSpeechRecognizer` (paquete `speech_to_text`, ~2 s de pausa), `SpeechFailure` (`permissionDenied`, `unavailable`, `network`, `failed`), `speechFailureMessage` |
| Parser de frases | `lib/services/voice_transaction_parser.dart` (`VoiceTransactionParser`, `VoiceTransactionDraft` con `withType/withAmount/withCategory/withDate`, `VoiceVehicle`) |
| Números en español | `lib/utils/spanish_number_parser.dart` |
| Estado de la captura | `lib/providers/voice_capture_controller.dart`: `VoiceCaptureController` (idle → listening → processing → ready / noSpeech / error), `soundLevel`, `elapsed`, `selectedCarId`, ediciones, `canSave`, `toTransaction`, `release()`, `cancel()`. Lógica pura, reconocedor y reloj inyectables |
| Hoja de voz | `lib/widgets/voice_entry_sheet.dart`: `VoiceEntrySheet`, resultado `VoiceEntrySaved` / `VoiceEntryManual` (recognizer, userId, ajustes, vibración y reloj inyectables) |
| Entrada + deshacer | `TransactionModalHelper.showVoiceTransactionSheet` (`lib/utils/transaction_modal_helper.dart`); `TransactionProvider.addReturningId` |
| Colores | `MyCarColors.income/incomeLight/expense/expenseLight/scrim/surfaceMuted/borderLight/textLabel` |
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
- Plugin nativo ausente: si la app instalada se compiló antes de agregar `speech_to_text`, la llamada lanza
  `MissingPluginException`. Se captura y se muestra "no hay reconocimiento de voz disponible"; la solución es
  detener la app y recompilar (`flutter clean && flutter pub get`, y `pod install` en iOS), no basta con hot reload/restart.

## Tests
- `test/helpers/fake_speech_recognizer.dart`: reconocedor falso compartido (`say`, `level`, `fail`, `finishWithoutFinalResult`).
- `test/services/voice_transaction_parser_test.dart`: frases del rediseño (chips de ejemplo, montos, tipo, categoría, fecha,
  vehículo), ediciones del borrador y `toTransaction`. `test/utils/spanish_number_parser_test.dart`.
- `test/services/speech_failure_test.dart`: traducción de errores del motor y mensajes.
- `test/providers/voice_capture_controller_test.dart`: estados, parciales, final tardío, stop/release/cancel, vehículo, edición,
  volumen y cronómetro.
- `test/widgets/voice_entry_sheet_test.dart`: los 3 pasos, medidas (104/156 px, botones 52, áreas >= 44), onda de 32 barras,
  cronómetro, vibración, selectores, guardar, errores y permisos.
- `test/utils/voice_sheet_helper_test.dart`: "Gasto guardado" con Deshacer, refresco, y "Registrar a mano" abre el formulario.
- `test/widgets/add_transaction_screen_test.dart` (grupo `voice input`): el formulario, incluido guardar mientras escucha.
- No se prueba `DeviceSpeechRecognizer` (motor nativo, nivel de sonido, silencio de 2 s) ni que los iconos de micrófono abran la
  hoja (crearía el motor nativo): **verificar a mano** en el simulador y en un iPhone real.

## Pendiente
- Interpretar el texto con un LLM (por ejemplo Claude vía una Edge Function de Supabase, nunca con la API key en la app)
  usando `VoiceTransactionParser` como respaldo sin conexión. La salida debe seguir siendo un `VoiceTransactionDraft`.
- Soportar otras monedas e inglés.
