import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/vehicle_modal_helper.dart';
import 'screens/add_income_screen.dart';
import 'screens/vehicles_list_screen.dart';
import 'screens/incomes_list_screen.dart';
import 'screens/car_incomes_screen.dart';
import 'screens/car_detail_screen.dart';
import 'screens/alerts_list_screen.dart';
import 'screens/add_alert_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/app_provider.dart';
import 'providers/car_provider.dart';
import 'providers/income_provider.dart';
import 'providers/user_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/subscription_provider.dart';
import 'utils/app_theme.dart';
import 'utils/income_modal_helper.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'config/supabase_config.dart';
import 'config/app_config.dart';

void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar locales para español
  await initializeDateFormatting('es_ES', null);
  Intl.defaultLocale = 'es_ES';

  // Configurar captura básica de errores antes de runApp
  _setupBasicErrorHandling();

  // Inicializar Supabase
  try {
    await SupabaseConfig.initialize();
    print('✅ Supabase inicializado correctamente');
  } catch (e) {
    print('⚠️ Error al inicializar Supabase: $e');
    print('⚠️ Asegúrate de configurar las credenciales en lib/config/supabase_config.dart');
  }

  // Inicializar servicio de notificaciones
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();
    print('✅ Servicio de notificaciones inicializado correctamente');
  } catch (e) {
    print('⚠️ Error al inicializar notificaciones: $e');
  }

  // Inicializar RevenueCat (SubscriptionService)
  try {
    await SubscriptionService.instance.initialize();
    print('✅ RevenueCat inicializado correctamente');
  } catch (e) {
    print('⚠️ Error al inicializar RevenueCat: $e');
    print('⚠️ Las suscripciones pueden no funcionar correctamente');
  }

  // Inicializar la base de datos antes de ejecutar la app
  await _initializeDatabase();

  runApp(const MyCarApp());
}

Future<void> _initializeDatabase() async {
  try {
    print('🚀 Inicializando base de datos...');
    final dbHelper = DatabaseHelper.instance;
    
    // Verificar si Supabase está inicializado antes de intentar conectarse
    try {
      final supabaseClient = SupabaseConfig.client;
      // Intentar una operación simple para verificar la conexión (sin requerir autenticación)
      await supabaseClient.from('cars').select('id').limit(0).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Timeout al conectar con Supabase. Verifica tu conexión a internet.');
        },
      );
      print('✅ Conexión con Supabase verificada');
    } catch (e) {
      print('⚠️ No se pudo conectar con Supabase: $e');
      print('⚠️ La aplicación funcionará en modo offline. Algunas funciones pueden estar limitadas.');
      print('⚠️ Verifica:');
      print('   1. Tu conexión a internet');
      print('   2. Que el proyecto de Supabase esté activo');
      print('   3. Que la URL en lib/config/supabase_config.dart sea correcta');
      print('   4. Que el proyecto Supabase no haya sido pausado o eliminado');
      // No lanzar el error, permitir que la app continúe
      return;
    }
    
    await dbHelper.initialize(); // Inicialización explícita
    print('✅ Base de datos inicializada correctamente');
    
    // Nota: No generamos datos de prueba aquí porque requiere autenticación
    // Los datos se generarán cuando el usuario inicie sesión
  } catch (e, stackTrace) {
    print('❌ Error al inicializar la base de datos: $e');
    print('Stack trace: $stackTrace');
    // No lanzar el error, permitir que la app continúe
    // Por ejemplo, mostrar un diálogo de error o cerrar la app
  }
}

void _setupBasicErrorHandling() {
  // Capturar errores de Flutter (widgets, UI)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logError('FLUTTER_ERROR', details.exception, details.stack);
  };
}

void _logError(String type, dynamic error, StackTrace? stack) {
  final timestamp = DateTime.now().toIso8601String();

  print('========================================');
  print('🚨 ERROR CAPTURADO GLOBALMENTE 🚨');
  print('========================================');
  print('Tipo: $type');
  print('Timestamp: $timestamp');
  print('Error: $error');
  print('Stack Trace: $stack');
  print('========================================');

  // Aquí podrías agregar lógica para:
  // - Enviar el error a un servicio de crash reporting (Firebase Crashlytics, Sentry, etc.)
  // - Guardar el error localmente para debugging
  // - Mostrar un snackbar al usuario (con cuidado de no causar más errores)
}

void _setupPlatformErrorHandling() {
  // Capturar errores de plataforma (async, isolates)
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    _logError('PLATFORM_ERROR', error, stack);
    return true; // Indicar que el error fue manejado
  };
}

class MyCarApp extends StatelessWidget {
  const MyCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Configurar captura de errores de plataforma después de la inicialización
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPlatformErrorHandling();
    });
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => CarProvider()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..listenToAuthChanges()),
        ChangeNotifierProvider(create: (_) => UserProvider()..loadUser()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp.router(
            title: 'MyCar',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appProvider.themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: AppConfig.isDevMode ? '/onboarding' : '/',
  redirect: (BuildContext context, GoRouterState state) async {
    // Obtener providers de forma segura
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      
      final isAuthenticated = authProvider.isAuthenticated;
      
      final isOnboardingRoute = state.uri.path == '/onboarding';
      final isAuthRoute = state.uri.path == '/login' || 
                          state.uri.path == '/register' || 
                          state.uri.path == '/forgot-password';
      final isHomeRoute = state.uri.path == '/' || state.uri.path == '/home';
      
      // En modo dev: mostrar onboarding siempre al iniciar (ruta raíz)
      // En modo prod: verificar preferencias guardadas
      if (AppConfig.isDevMode) {
        // En modo dev:
        // - Si está autenticado, no puede ir a onboarding (redirigir a home)
        // - Si no está autenticado y navega a home, redirigir a login (no onboarding)
        // - El onboarding solo se muestra cuando se navega explícitamente a /onboarding
        
        if (isAuthenticated) {
          // Usuario autenticado: proteger rutas de auth y onboarding
          if (isAuthRoute || isOnboardingRoute) {
            return '/';
          }
        } else {
          // Usuario NO autenticado: redirigir home a login
          if (isHomeRoute && !isAuthRoute && !isOnboardingRoute) {
            return '/login';
          }
        }
        // Permitir navegación libre en otras rutas
        return null;
      } else {
        // Modo prod: comportamiento normal con preferencias guardadas
        final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
        
        // Si no completó onboarding, redirigir a onboarding (excepto si ya está ahí)
        if (!onboardingCompleted && !isOnboardingRoute) {
          return '/onboarding';
        }
        
        // Si completó onboarding pero no está autenticado, redirigir a login (excepto si ya está en auth)
        if (onboardingCompleted && !isAuthenticated && !isAuthRoute) {
          return '/login';
        }
        
        // Si está autenticado y trata de ir a login/register/onboarding, redirigir a home
        if (isAuthenticated && (isAuthRoute || isOnboardingRoute)) {
          return '/';
        }
      }
      
      return null; // No redirigir
    } catch (e) {
      // Si hay error al acceder a providers, permitir navegación normal
      debugPrint('Error en redirect: $e');
      return null;
    }
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) {
        // Obtener el índice del tab desde query parameters
        final tabParam = state.uri.queryParameters['tab'];
        int initialIndex = 0;
        if (tabParam == 'incomes') {
          initialIndex = 1;
        } else if (tabParam == 'alerts') {
          initialIndex = 2;
        } else if (tabParam == 'profile') {
          initialIndex = 3;
        } else if (tabParam == 'settings') {
          initialIndex = 4;
        }
        return MainNavigationScreen(initialIndex: initialIndex);
      },
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/add-income',
      builder: (context, state) => const AddIncomeScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      builder: (context, state) => const VehiclesListScreen(),
    ),
    GoRoute(
      path: '/incomes',
      builder: (context, state) => const IncomesListScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertsListScreen(),
    ),
    GoRoute(
      path: '/add-alert',
      builder: (context, state) => const AddAlertScreen(),
    ),
    GoRoute(
      path: '/car-incomes',
      builder: (context, state) {
        final carIdStr = state.uri.queryParameters['carId'];
        if (carIdStr == null || carIdStr.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Error: carId no proporcionado')),
          );
        }
        return CarIncomesScreen(carId: carIdStr);
      },
    ),
    GoRoute(
      path: '/car-detail',
      builder: (context, state) {
        final carIdStr = state.uri.queryParameters['carId'];
        if (carIdStr == null || carIdStr.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Error: carId no proporcionado')),
          );
        }
        return CarDetailScreen(carId: carIdStr);
      },
    ),
  ],
);

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // Cargar vehículos al iniciar la app
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final carProvider = Provider.of<CarProvider>(context, listen: false);
      await carProvider.loadCars();
      // Si no hay carros después de cargar, esperar un poco y recargar
      // (por si los datos de prueba se están generando)
      if (carProvider.cars.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        await carProvider.loadCars();
      }
    });
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const IncomesListScreen(),
    const AlertsListScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Home
                  _buildNavItem(
                    context,
                    icon: Icons.home,
                    label: 'Home',
                    index: 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  // Ingresos
                  _buildNavItem(
                    context,
                    icon: Icons.attach_money,
                    label: 'Ingresos',
                    index: 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  // Botón central de agregar vehículo
                  _buildCenterButton(context),
                  // Alertas
                  _buildNavItem(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'Alertas',
                    index: 2,
                    onTap: () => _onItemTapped(2),
                  ),
                  // Settings
                  _buildNavItem(
                    context,
                    icon: Icons.settings,
                    label: 'Settings',
                    index: 3,
                    onTap: () => _onItemTapped(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;
    return Flexible(
      flex: 1,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        child: InkWell(
          onTap: () {
            debugPrint('Botón flotante presionado. Índice seleccionado: $_selectedIndex');
            // Si estamos en la sección de Ingresos (índice 1), abrir modal de agregar ingreso
            if (_selectedIndex == 1) {
              debugPrint('Abriendo modal de agregar ingreso');
              IncomeModalHelper.showAddIncomeModal(context);
            } else if (_selectedIndex == 2) {
              // Si estamos en Alertas (índice 2), navegar a agregar alerta
              debugPrint('Navegando a agregar alerta');
              context.push('/add-alert');
            } else {
              // En otras secciones, abrir modal de agregar vehículo
              debugPrint('Abriendo modal de agregar vehículo');
              VehicleModalHelper.showAddVehicleModal(context);
            }
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
