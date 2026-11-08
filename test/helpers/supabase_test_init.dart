import 'package:supabase_flutter/supabase_flutter.dart';

/// Inicializa Supabase con valores falsos para tests que construyen un
/// `SupabaseClient` (p. ej. `AuthProvider`). No hace llamadas de red y no
/// depende del `.env`.
Future<void> initSupabaseForTests() async {
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    anonKey: 'test-anon-key',
  );
}
