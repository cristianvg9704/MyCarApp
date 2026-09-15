import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Utilidades para convertir imágenes de vehículos a/desde base64.
///
/// La imagen se guarda como una cadena base64 en la columna `image_base64`
/// de la tabla `cars` en Supabase, y se decodifica en el cliente para
/// mostrarla con `Image.memory`. De esta forma la imagen queda persistida en
/// la nube y no depende de rutas locales temporales.
class VehicleImage {
  /// Lee el archivo en [path] y lo devuelve codificado en base64 (sin prefijo).
  ///
  /// Devuelve `null` si [path] es nulo/vacío o el archivo no existe.
  static Future<String?> encodeFile(String? path) async {
    if (path == null || path.trim().isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Decodifica una cadena base64 a bytes listos para `Image.memory`.
  ///
  /// Acepta cadenas con o sin prefijo `data:image/...;base64,`.
  /// Devuelve `null` si la cadena es nula, vacía o inválida.
  static Uint8List? decode(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;

    var normalized = base64String.trim();
    final commaIndex = normalized.indexOf(',');
    if (normalized.startsWith('data:') && commaIndex != -1) {
      normalized = normalized.substring(commaIndex + 1);
    }

    try {
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }
}
