import 'package:flutter/foundation.dart';

/// Los logs de la app solo deben verse al depurar.
///
/// `debugPrint` imprime también en builds release, así que en producción se
/// reemplaza por una función vacía. En debug/profile no se toca.
///
/// [isRelease] es inyectable para poder probarlo; por defecto usa `kReleaseMode`.
void configureLogging({bool isRelease = kReleaseMode}) {
  if (!isRelease) return;
  debugPrint = (String? message, {int? wrapWidth}) {};
}
