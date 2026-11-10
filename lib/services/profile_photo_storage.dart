import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Guarda la foto de perfil en el almacenamiento de la app.
///
/// `image_picker` entrega un archivo temporal que el sistema puede borrar.
/// Se copia al directorio de documentos para que la foto siga ahí al reabrir
/// la app. La foto de perfil permanece en el dispositivo (no se sube).
class ProfilePhotoStorage {
  static const _prefix = 'profile_photo_';

  final Future<Directory> Function() _documentsDir;
  final DateTime Function() _now;

  ProfilePhotoStorage({
    Future<Directory> Function()? documentsDir,
    DateTime Function()? now,
  }) : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now;

  /// Copia [sourcePath] al directorio de la app y devuelve la nueva ruta.
  /// Si [replacing] era una foto guardada por esta clase, la borra.
  Future<String> save(String sourcePath, {String? replacing}) async {
    final dir = await _documentsDir();
    final dot = sourcePath.lastIndexOf('.');
    final slash = sourcePath.lastIndexOf(Platform.pathSeparator);
    final extension = dot > slash ? sourcePath.substring(dot) : '.jpg';
    final target = File(
      '${dir.path}${Platform.pathSeparator}'
      '$_prefix${_now().millisecondsSinceEpoch}$extension',
    );

    await File(sourcePath).copy(target.path);
    if (replacing != null) await _deleteIfOurs(replacing, dir);
    return target.path;
  }

  Future<void> _deleteIfOurs(String path, Directory dir) async {
    final file = File(path);
    final name = path.split(Platform.pathSeparator).last;
    final isOurs = name.startsWith(_prefix) && file.parent.path == dir.path;
    if (!isOurs) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Una foto vieja que no se pudo borrar no debe impedir guardar la nueva.
    }
  }
}
