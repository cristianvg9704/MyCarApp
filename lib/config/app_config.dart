/// Enum para definir los entornos disponibles
enum AppEnvironment {
  dev,
  prod,
}

/// Configuración centralizada del entorno de la aplicación
/// Controla el comportamiento entre modo desarrollo y producción
class AppConfig {
  /// Entorno actual de la aplicación
  /// Cambiar a AppEnvironment.prod para producción
  static const AppEnvironment _environment = AppEnvironment.dev;

  /// Verifica si la app está en modo desarrollo
  static bool get isDevMode => _environment == AppEnvironment.dev;

  /// Verifica si la app está en modo producción
  static bool get isProdMode => _environment == AppEnvironment.prod;

  /// Obtiene el entorno actual como string
  static String get environmentName => _environment.name;
}
