import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://sdnwjwwdclatyqvngidu.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkbndqd3dkY2xhdHlxdm5naWR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NzE0NDYsImV4cCI6MjA4NjE0NzQ0Nn0.eSyRXB43OKaKYCftUuq0ebl6p6iJxxCsf9I0I7MR9EU';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
