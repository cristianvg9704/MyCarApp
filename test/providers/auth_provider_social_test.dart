import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/supabase_test_init.dart';
import 'package:new_my_car_app/providers/auth_provider.dart';
import 'package:new_my_car_app/services/social_auth_service.dart';

class _FakeSocialAuthService implements SocialAuthService {
  SocialSignInResult result = SocialSignInResult.signedIn;
  Object? error;
  bool appleAvailable = true;
  final List<SocialProvider> calls = [];

  @override
  bool isAvailable(SocialProvider provider) =>
      provider == SocialProvider.google || appleAvailable;

  @override
  Future<SocialSignInResult> signIn(SocialProvider provider) async {
    calls.add(provider);
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  // AuthProvider construye un SupabaseClient en su inicializador de campo,
  // así que Supabase debe estar inicializado antes de poder crearlo en un test.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initSupabaseForTests();
  });

  late _FakeSocialAuthService social;
  late AuthProvider provider;

  setUp(() {
    social = _FakeSocialAuthService();
    provider = AuthProvider(socialAuthService: social);
  });

  group('AuthProvider.signInWithSocial', () {
    test('returns true and forwards the provider on success', () async {
      final apple = await provider.signInWithSocial(SocialProvider.apple);
      final google = await provider.signInWithSocial(SocialProvider.google);

      expect(apple, isTrue);
      expect(google, isTrue);
      expect(social.calls, [SocialProvider.apple, SocialProvider.google]);
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('toggles isLoading and notifies on start and completion', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.signInWithSocial(SocialProvider.google);

      expect(states.first, isTrue);
      expect(states.last, isFalse);
    });

    test(
      'a cancelled sign-in returns false without an error message',
      () async {
        social.result = SocialSignInResult.cancelled;

        final result = await provider.signInWithSocial(SocialProvider.apple);

        expect(result, isFalse);
        expect(provider.errorMessage, isNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test('shows the message of a SocialAuthException', () async {
      social.error = const SocialAuthException(
        'Google aún no está configurado.',
      );

      final result = await provider.signInWithSocial(SocialProvider.google);

      expect(result, isFalse);
      expect(provider.errorMessage, 'Google aún no está configurado.');
      expect(provider.isLoading, isFalse);
    });

    test('hides technical errors behind a generic message', () async {
      social.error = Exception('AuthApiException: invalid jwt');

      final result = await provider.signInWithSocial(SocialProvider.apple);

      expect(result, isFalse);
      expect(
        provider.errorMessage,
        'No se pudo iniciar sesión. Intenta de nuevo.',
      );
      expect(provider.errorMessage, isNot(contains('jwt')));
    });

    test('clears a previous error when retrying', () async {
      social.error = const SocialAuthException('falló');
      await provider.signInWithSocial(SocialProvider.google);
      expect(provider.errorMessage, isNotNull);

      social.error = null;
      final result = await provider.signInWithSocial(SocialProvider.google);

      expect(result, isTrue);
      expect(provider.errorMessage, isNull);
    });
  });

  group('AuthProvider.isSocialProviderAvailable', () {
    test('delegates to the service', () {
      social.appleAvailable = false;

      expect(provider.isSocialProviderAvailable(SocialProvider.apple), isFalse);
      expect(provider.isSocialProviderAvailable(SocialProvider.google), isTrue);
    });
  });

  group('asociar las compras a la cuenta', () {
    test(
      'al iniciar sesión con Apple/Google llama onSignedIn con el id',
      () async {
        final ids = <String>[];
        final linked = AuthProvider(
          socialAuthService: social,
          onSignedIn: (id) async => ids.add(id),
          currentUserId: () => 'user-123',
        );

        await linked.signInWithSocial(SocialProvider.google);

        expect(ids, ['user-123']);
      },
    );

    test('si el usuario cancela no asocia nada', () async {
      social.result = SocialSignInResult.cancelled;
      final ids = <String>[];
      final linked = AuthProvider(
        socialAuthService: social,
        onSignedIn: (id) async => ids.add(id),
        currentUserId: () => 'user-123',
      );

      final ok = await linked.signInWithSocial(SocialProvider.apple);

      expect(ok, isFalse);
      expect(ids, isEmpty);
    });

    test('si falla el inicio de sesión no asocia nada', () async {
      social.error = const SocialAuthException('x');
      final ids = <String>[];
      final linked = AuthProvider(
        socialAuthService: social,
        onSignedIn: (id) async => ids.add(id),
        currentUserId: () => 'user-123',
      );

      await linked.signInWithSocial(SocialProvider.google);

      expect(ids, isEmpty);
    });

    test('sin id de usuario no llama a onSignedIn', () async {
      final ids = <String>[];
      final linked = AuthProvider(
        socialAuthService: social,
        onSignedIn: (id) async => ids.add(id),
        currentUserId: () => null,
      );

      await linked.signInWithSocial(SocialProvider.google);

      expect(ids, isEmpty);
    });

    test('un error al asociar las compras no impide entrar', () async {
      final linked = AuthProvider(
        socialAuthService: social,
        onSignedIn: (_) async => throw Exception('RevenueCat caído'),
        currentUserId: () => 'user-123',
      );

      final ok = await linked.signInWithSocial(SocialProvider.google);

      expect(ok, isTrue);
      expect(linked.errorMessage, isNull);
    });

    test('al cerrar sesión desvincula las compras', () async {
      var loggedOut = 0;
      final linked = AuthProvider(
        socialAuthService: social,
        onSignedOut: () async => loggedOut++,
      );

      await linked.signOut();

      expect(loggedOut, 1);
    });

    test('un error al desvincular no deja la sesión a medias', () async {
      final linked = AuthProvider(
        socialAuthService: social,
        onSignedOut: () async => throw Exception('RevenueCat caído'),
      );

      await linked.signOut();

      expect(linked.errorMessage, isNull);
      expect(linked.isLoading, isFalse);
    });
  });
}
