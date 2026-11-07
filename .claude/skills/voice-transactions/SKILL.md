---
name: voice-transactions
description: Registro de ingresos y egresos por voz (reconocimiento del dispositivo + parser local en español). Úsalo al tocar el botón de voz, SpeechRecognizer, el parser de frases, los permisos de micrófono o al integrar IA para interpretar el audio.
---

# Registro por voz

El usuario dice una frase ("gasté cincuenta mil en gasolina ayer") y el formulario de movimientos se llena solo.
No se guarda nada automáticamente: el usuario revisa y pulsa **Guardar** (la voz puede equivocarse).
**Sin IA ni red propia**: voz a texto con el motor nativo del dispositivo y un parser por reglas. Integrar un LLM queda
pendiente (ver al final).

## Flujo
1. Entradas con el vehículo ya elegido:
   - Detalle del vehículo → icono de micrófono en el AppBar (`CarDetailScreen`).
   - Finanzas → icono de micrófono en la tarjeta de cada vehículo (`FinancesListScreen`).
   Ambas abren `TransactionModalHelper.showAddTransactionModal(context, carId:, startWithVoice: true)` y empiezan a escuchar.
2. También hay un botón **Registrar por voz** dentro del formulario (`AddTransactionScreen`); ahí el vehículo se
   elige en el selector (obligatorio al guardar).
3. `SpeechRecognizer` entrega resultados parciales (se muestran como transcripción) y uno final.
4. `VoiceTransactionParser.parse` convierte el texto en un `VoiceTransactionDraft` y el formulario se rellena:
   tipo, categoría, monto, descripción, fecha, litros y kilometraje. Si no se entendió el monto, se avisa y queda vacío.

## Capas
| Capa | Archivo |
|---|---|
| Reconocimiento | `lib/services/speech_recognizer.dart`: `SpeechRecognizer` (abstracta), `DeviceSpeechRecognizer` (paquete `speech_to_text`), `SpeechFailure` |
| Parser de frases | `lib/services/voice_transaction_parser.dart` (`VoiceTransactionParser`, `VoiceTransactionDraft`) |
| Números en español | `lib/utils/spanish_number_parser.dart` (`tokenizeSpanish`, `extractSpokenNumbers`, `normalizeSpanish`) |
| UI | `AddTransactionScreen` (`speechRecognizer` y `startWithVoice` inyectables) |

## Reglas del parser (español de Colombia)
- **Tipo:** verbos fuertes de egreso (gasté, pagué, compré, tanqueé, eché…) o de ingreso (me pagaron, ingreso, cobré, gané,
  recibí, vendí…). Si aparecen ambos gana el primero. Sin verbos, una palabra de categoría implica egreso; si no, se usa el
  tipo actual del formulario.
- **Categoría (solo egresos):** combustible (gasolina, tanqueo, acpm, gas, litros, galones), mantenimiento (aceite, mecánico,
  taller, llantas, frenos, filtro, revisión…), otros (peaje, parqueadero, lavado, multa, soat…). Sin palabra clave: otros
  (o combustible si hay litros). Primera palabra que aparece gana.
- **Monto:** números con dígitos (`50.000`, `$50.000`, `80 mil`, `1,5 millones`), con palabras (`ciento veinte mil`) o
  jerga (`80 lucas`). Se excluyen los números ya usados como litros, galones, km o fecha, y el artículo "un/una".
  Si hay varios, prefiere el marcado con `$` o "pesos"; si no, el mayor.
- **Litros / galones:** `10 litros`; los galones se convierten (1 gal = 3,785 L, 2 decimales).
- **Kilometraje:** `45200 km`, `45 mil kilómetros`, `kilometraje 45200`. Solo se conserva en combustible y mantenimiento.
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
- `test/widgets/add_transaction_screen_test.dart` (grupo `voice input`): reconocedor falso; escucha, transcripción parcial,
  llenado del formulario, guardado tras confirmar, permisos, errores, `startWithVoice` y cancelación al salir.
- `test/widgets/car_detail_screen_test.dart`: el AppBar ofrece la acción de voz.
- No se prueba `DeviceSpeechRecognizer` (depende del motor nativo): verificar a mano en un dispositivo real.

## Pendiente
- Interpretar el texto con un LLM (por ejemplo Claude vía una Edge Function de Supabase, nunca con la API key en la app)
  usando `VoiceTransactionParser` como respaldo sin conexión. La salida debe seguir siendo un `VoiceTransactionDraft`.
- Asociar el vehículo por voz ("en el Corolla") cuando se registra desde Finanzas sin vehículo elegido.
- Soportar otras monedas e inglés.
