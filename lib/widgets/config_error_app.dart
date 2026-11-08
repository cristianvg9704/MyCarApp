import 'package:flutter/material.dart';
import '../utils/my_car_colors.dart';

/// Pantalla que reemplaza a la app cuando faltan claves del `.env`
/// (se ejecutó sin `--dart-define-from-file=.env`). Sin ella la app seguiría
/// arrancando y fallaría más adelante con un error difícil de entender.
class ConfigErrorApp extends StatelessWidget {
  /// Nombres de las variables que faltan (p. ej. `SUPABASE_URL`).
  final List<String> missing;

  const ConfigErrorApp({super.key, required this.missing});

  /// Comando correcto para ejecutar la app.
  static const String runCommand = 'flutter run --dart-define-from-file=.env';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: MyCarColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.settings_suggest_outlined,
                    size: 56,
                    color: MyCarColors.warning,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Falta configuración',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: MyCarColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'La app se ejecutó sin las claves del archivo .env. '
                    'Falta definir:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: MyCarColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final name in missing)
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w600,
                        color: MyCarColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MyCarColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MyCarColors.border),
                    ),
                    child: const SelectableText(
                      runCommand,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: MyCarColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Si no tienes .env, copia .env.example a .env y rellénalo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: MyCarColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
