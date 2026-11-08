import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/config/app_env.dart';
import 'package:new_my_car_app/config/supabase_config.dart';

void main() {
  group('AppEnv.missing', () {
    test('lists only the empty or blank variables', () {
      expect(
        AppEnv.missing({'A': 'x', 'B': '', 'C': '   ', 'D': 'y'}),
        ['B', 'C'],
      );
    });

    test('is empty when everything is set', () {
      expect(AppEnv.missing({'A': 'x'}), isEmpty);
    });
  });

  group('AppEnv.missingMessage', () {
    test('names the variables and how to fix it', () {
      final message = AppEnv.missingMessage(['SUPABASE_URL']);
      expect(message, contains('SUPABASE_URL'));
      expect(message, contains('--dart-define-from-file=.env'));
    });
  });

  group('SupabaseConfig.missingVariables', () {
    test('reports both variables when nothing is defined', () {
      expect(SupabaseConfig.missingVariables(url: '', anonKey: ''), [
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
      ]);
    });

    test('is empty when both are defined', () {
      expect(SupabaseConfig.missingVariables(url: 'u', anonKey: 'k'), isEmpty);
    });
  });

  group('SupabaseConfig.initialize', () {
    test('fails with a clear message when the URL is missing', () {
      expect(
        () => SupabaseConfig.initialize(url: '', anonKey: 'key'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });

    test('names every missing variable', () {
      expect(
        () => SupabaseConfig.initialize(url: '', anonKey: ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('SUPABASE_URL'), contains('SUPABASE_ANON_KEY')),
          ),
        ),
      );
    });
  });
}
