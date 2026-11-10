import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/my_car_palette.dart';

/// Foto de perfil circular. Muestra la foto del usuario si existe y, si no se
/// puede leer, la imagen por defecto (y como último recurso un icono).
class UserAvatar extends StatelessWidget {
  static const defaultAsset = 'assets/images/defaultUser.jpg';

  final String? photoPath;
  final double iconSize;

  const UserAvatar({super.key, required this.photoPath, this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Image.asset(
    defaultAsset,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) =>
        Icon(Icons.person, size: iconSize, color: context.palette.textSecondary),
  );
}
