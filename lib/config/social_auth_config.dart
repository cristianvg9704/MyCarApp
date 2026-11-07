/// Identificadores para iniciar sesión con Google. No son secretos, pero
/// dependen de tu proyecto de Google Cloud (ver `docs/SOCIAL_AUTH_SETUP.md`).
///
/// Se pueden fijar aquí o pasar al compilar:
/// `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=... --dart-define=GOOGLE_IOS_CLIENT_ID=...`
class SocialAuthConfig {
  SocialAuthConfig._();

  /// OAuth client ID de tipo **Web**. Es el mismo que se configura en
  /// Supabase → Authentication → Providers → Google. Requerido en iOS y Android.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// OAuth client ID de tipo **iOS**. Requerido solo en iOS.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;
}
