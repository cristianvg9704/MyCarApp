import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_my_car_app/config/supabase_config.dart';
import 'package:new_my_car_app/providers/auth_provider.dart';
import 'package:new_my_car_app/services/account_service.dart';

class _FakeAccountService implements AccountService {
  Object? error;
  int calls = 0;

  @override
  Future<void> deleteAccount() async {
    calls++;
    if (error != null) throw error!;
  }
}

void main() {
  // AuthProvider construye un SupabaseClient en su inicializador de campo,
  // así que Supabase debe estar inicializado antes de poder crearlo en un test.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  });

  late _FakeAccountService service;
  late AuthProvider provider;

  setUp(() {
    service = _FakeAccountService();
    provider = AuthProvider(accountService: service);
  });

  group('AuthProvider.deleteAccount', () {
    test('returns true and calls the account service', () async {
      final result = await provider.deleteAccount();

      expect(result, isTrue);
      expect(service.calls, 1);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('toggles isLoading and notifies on start and completion', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.deleteAccount();

      expect(states.first, isTrue);
      expect(states.last, isFalse);
    });

    test('returns false and sets a message when the service fails', () async {
      service.error = Exception('rpc failed');

      final result = await provider.deleteAccount();

      expect(result, isFalse);
      expect(provider.isLoading, isFalse);
      expect(
        provider.errorMessage,
        'No se pudo eliminar la cuenta. Intenta de nuevo.',
      );
    });

    test('does not leak the technical error to the user', () async {
      service.error = Exception('FK violation on public.alerts');

      await provider.deleteAccount();

      expect(provider.errorMessage, isNot(contains('FK')));
    });

    test('clears a previous error when retrying successfully', () async {
      service.error = Exception('boom');
      await provider.deleteAccount();
      expect(provider.errorMessage, isNotNull);

      service.error = null;
      final result = await provider.deleteAccount();

      expect(result, isTrue);
      expect(provider.errorMessage, isNull);
      expect(service.calls, 2);
    });
  });
}
