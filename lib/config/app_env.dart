/// Valores de configuración que no se guardan en el código: se inyectan al
/// compilar con `--dart-define-from-file=.env` (ver `.env.example`).
///
/// Se usa `dart-define` y no un paquete que lea `.env` en tiempo de ejecución
/// porque este último empaqueta el archivo dentro de la app como asset, donde
/// cualquiera puede extraerlo del IPA/APK.
class AppEnv {
  AppEnv._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String revenueCatIosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );
  static const String revenueCatAndroidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );

  /// Nombres de las variables vacías de [values] (clave → valor).
  static List<String> missing(Map<String, String> values) => [
    for (final entry in values.entries)
      if (entry.value.trim().isEmpty) entry.key,
  ];

  /// Mensaje listo para mostrar cuando faltan variables obligatorias.
  static String missingMessage(List<String> names) =>
      'Falta configuración: ${names.join(', ')}. '
      'Copia .env.example a .env y ejecuta con --dart-define-from-file=.env';
}
