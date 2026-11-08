import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/social_auth_config.dart';
import '../config/supabase_config.dart';
import '../utils/nonce_utils.dart';

enum SocialProvider { apple, google }

enum SocialSignInResult { signedIn, cancelled }

/// Fallo al iniciar sesión con un proveedor social. [message] está en español
/// y se puede mostrar al usuario.
class SocialAuthException implements Exception {
  final String message;
  const SocialAuthException(this.message);

  @override
  String toString() => 'SocialAuthException: $message';
}

/// Inicio de sesión/registro con Apple o Google. Abstracción para poder probar
/// `AuthProvider` y las pantallas sin plugins nativos ni Supabase.
abstract class SocialAuthService {
  /// Apple solo está disponible en iOS y macOS.
  bool isAvailable(SocialProvider provider);

  /// Autentica con el proveedor y abre sesión en Supabase. Crea la cuenta si es
  /// la primera vez. Devuelve [SocialSignInResult.cancelled] si el usuario
  /// cierra el diálogo; lanza [SocialAuthException] si falla.
  Future<SocialSignInResult> signIn(SocialProvider provider);
}

/// Implementación nativa: obtiene el token del SDK de Apple/Google y lo
/// intercambia por una sesión de Supabase (`signInWithIdToken`).
class DeviceSocialAuthService implements SocialAuthService {
  bool _googleInitialized = false;

  @override
  bool isAvailable(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.apple:
        return !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS);
      case SocialProvider.google:
        return true;
    }
  }

  @override
  Future<SocialSignInResult> signIn(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.apple:
        return _signInWithApple();
      case SocialProvider.google:
        return _signInWithGoogle();
    }
  }

  Future<SocialSignInResult> _signInWithApple() async {
    if (!isAvailable(SocialProvider.apple)) {
      throw const SocialAuthException(
        'Iniciar sesión con Apple no está disponible en este dispositivo.',
      );
    }

    // Apple recibe el hash del nonce; Supabase, el valor original.
    final rawNonce = generateRawNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256OfString(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialSignInResult.cancelled;
      }
      debugPrint('Error de Apple: ${e.code} ${e.message}');
      throw const SocialAuthException('No se pudo iniciar sesión con Apple.');
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const SocialAuthException(
        'Apple no devolvió una identidad válida.',
      );
    }

    final client = SupabaseConfig.client;
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple solo entrega el nombre la primera vez: se guarda en el perfil.
    final fullName = [
      credential.givenName,
      credential.familyName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    if (fullName.isNotEmpty) {
      try {
        await client.auth.updateUser(UserAttributes(data: {'name': fullName}));
      } catch (e) {
        debugPrint('No se pudo guardar el nombre de Apple: $e');
      }
    }
    return SocialSignInResult.signedIn;
  }

  Future<SocialSignInResult> _signInWithGoogle() async {
    if (!SocialAuthConfig.isGoogleConfigured) {
      throw const SocialAuthException(
        'El inicio de sesión con Google aún no está configurado.',
      );
    }

    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(
        clientId: SocialAuthConfig.googleIosClientId.isEmpty
            ? null
            : SocialAuthConfig.googleIosClientId,
        serverClientId: SocialAuthConfig.googleWebClientId,
      );
      _googleInitialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return SocialSignInResult.cancelled;
      }
      debugPrint('Error de Google: ${e.code} ${e.description}');
      throw const SocialAuthException('No se pudo iniciar sesión con Google.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const SocialAuthException(
        'Google no devolvió una identidad válida.',
      );
    }

    await SupabaseConfig.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    return SocialSignInResult.signedIn;
  }
}
