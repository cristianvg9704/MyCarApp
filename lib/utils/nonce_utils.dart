import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

const String _nonceCharset =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';

/// Cadena aleatoria criptográficamente segura para el flujo de Apple.
String generateRawNonce([int length = 32]) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => _nonceCharset[random.nextInt(_nonceCharset.length)],
  ).join();
}

/// SHA-256 en hexadecimal. Apple recibe el hash y Supabase el valor original.
String sha256OfString(String input) =>
    sha256.convert(utf8.encode(input)).toString();
