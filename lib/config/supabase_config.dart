import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_env.dart';

class SupabaseConfig {
  static const String supabaseUrl = AppEnv.supabaseUrl;
  static const String supabaseAnonKey = AppEnv.supabaseAnonKey;

  /// [url] y [anonKey] se pueden sustituir (por defecto vienen del `.env`).
  /// Lanza un [StateError] claro si falta alguno, en vez de fallar después con
  /// un error de red difícil de interpretar.
  static Future<void> initialize({
    String url = supabaseUrl,
    String anonKey = supabaseAnonKey,
  }) async {
    final missing = AppEnv.missing({
      'SUPABASE_URL': url,
      'SUPABASE_ANON_KEY': anonKey,
    });
    if (missing.isNotEmpty) {
      throw StateError(AppEnv.missingMessage(missing));
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
