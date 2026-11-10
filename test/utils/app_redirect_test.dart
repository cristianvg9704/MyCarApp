import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/app_redirect.dart';

void main() {
  String? go({
    bool isAuthenticated = false,
    bool hasPlan = false,
    bool onboardingCompleted = false,
    required String path,
  }) => appRedirect(
    isAuthenticated: isAuthenticated,
    hasPlan: hasPlan,
    onboardingCompleted: onboardingCompleted,
    path: path,
  );

  group('primera vez (sin sesión, sin onboarding visto)', () {
    test('todo lleva al onboarding', () {
      for (final path in [
        '/',
        '/home',
        '/login',
        '/register',
        '/subscription',
      ]) {
        expect(go(path: path), '/onboarding', reason: path);
      }
    });

    test('ya en el onboarding se queda', () {
      expect(go(path: '/onboarding'), isNull);
    });
  });

  group('usuario que ya vio el onboarding, sin sesión', () {
    test('va al login desde cualquier ruta privada', () {
      for (final path in [
        '/',
        '/home',
        '/profile',
        '/subscription',
        '/onboarding',
      ]) {
        expect(
          go(onboardingCompleted: true, path: path),
          '/login',
          reason: path,
        );
      }
    });

    test('puede estar en login, registro y recuperar contraseña', () {
      for (final path in ['/login', '/register', '/forgot-password']) {
        expect(go(onboardingCompleted: true, path: path), isNull, reason: path);
      }
    });

    test('no vuelve a ver el onboarding', () {
      expect(go(onboardingCompleted: true, path: '/onboarding'), '/login');
    });
  });

  group('usuario normal: con sesión y suscripción activa entra directo', () {
    String? normal(String path, {bool onboardingCompleted = true}) => go(
      isAuthenticated: true,
      hasPlan: true,
      onboardingCompleted: onboardingCompleted,
      path: path,
    );

    test('no ve onboarding, login ni planes al abrir la app', () {
      expect(normal('/'), isNull);
      expect(normal('/home'), isNull);
      expect(normal('/car-detail'), isNull);
    });

    test('si abre login, registro u onboarding lo devuelve al inicio', () {
      for (final path in [
        '/login',
        '/register',
        '/forgot-password',
        '/onboarding',
      ]) {
        expect(normal(path), '/', reason: path);
      }
    });

    test('no importa si el onboarding quedó sin marcar (cuenta existente)', () {
      expect(normal('/', onboardingCompleted: false), isNull);
      expect(normal('/onboarding', onboardingCompleted: false), '/');
    });

    test('puede abrir los planes desde Ajustes', () {
      expect(normal('/subscription'), isNull);
    });
  });

  group('con sesión pero sin suscripción: solo los planes', () {
    String? noPlan(String path) =>
        go(isAuthenticated: true, onboardingCompleted: true, path: path);

    test('cualquier ruta lleva a los planes', () {
      for (final path in ['/', '/home', '/login', '/onboarding', '/profile']) {
        expect(noPlan(path), '/subscription', reason: path);
      }
    });

    test('en los planes no hay redirección (sin bucle)', () {
      expect(noPlan('/subscription'), isNull);
    });
  });
}
