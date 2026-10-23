import '../models/car.dart';
import '../models/car_transaction.dart';
import '../models/alert.dart';
import '../models/mileage_reading.dart';
import '../models/maintenance_log.dart';
import '../models/trip_log.dart';
import '../config/supabase_config.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  /// Verifica que haya un usuario autenticado
  /// Lanza una excepción si no hay usuario autenticado
  String _requireAuth() {
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null || currentUser.id.isEmpty) {
      throw Exception('Usuario no autenticado. Por favor inicia sesión.');
    }
    return currentUser.id;
  }

  // ============================================
  // MÉTODOS PARA CARS
  // ============================================

  Future<String> insertCar(Car car) async {
    final userId = _requireAuth();
    
    // Asegurar que el car tenga el user_id correcto
    final carData = car.toMap();
    carData['user_id'] = userId;
    
    final response = await SupabaseConfig.client
        .from('cars')
        .insert(carData)
        .select('id')
        .single();
    
    return response['id'] as String;
  }

  Future<List<Car>> getAllCars() async {
    _requireAuth();
    
    // RLS automáticamente filtra por user_id, no necesitamos agregar .eq('user_id', userId)
    final response = await SupabaseConfig.client
        .from('cars')
        .select()
        .order('year', ascending: false);
    
    return response
        .map<Car>((map) => Car.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<Car?> getCar(String id) async {
    _requireAuth();
    
    try {
      final response = await SupabaseConfig.client
          .from('cars')
          .select()
          .eq('id', id)
          .single();
      
      return Car.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      // Si no se encuentra el carro o no pertenece al usuario, RLS retornará error
      return null;
    }
  }

  Future<void> updateCar(Car car) async {
    _requireAuth();
    
    if (car.id == null) {
      throw Exception('No se puede actualizar un carro sin ID');
    }
    
    final updateData = car.toMap();
    // Remover id y user_id del update (no se deben actualizar)
    updateData.remove('id');
    updateData.remove('user_id');
    updateData['updated_at'] = DateTime.now().toIso8601String();
    
    await SupabaseConfig.client
        .from('cars')
        .update(updateData)
        .eq('id', car.id!);
  }

  Future<void> deleteCar(String id) async {
    _requireAuth();
    
    await SupabaseConfig.client
        .from('cars')
        .delete()
        .eq('id', id);
  }

  // ============================================
  // MÉTODOS PARA MOVIMIENTOS (ingresos y egresos)
  // ============================================

  static const String _transactionsTable = 'car_transactions';

  Future<String> insertTransaction(CarTransaction transaction) async {
    final userId = _requireAuth();

    // Asegurar que el movimiento tenga el user_id correcto
    final data = transaction.toMap();
    data['user_id'] = userId;

    final response = await SupabaseConfig.client
        .from(_transactionsTable)
        .insert(data)
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<CarTransaction>> getAllTransactions() async {
    _requireAuth();

    // RLS automáticamente filtra por user_id
    final response = await SupabaseConfig.client
        .from(_transactionsTable)
        .select()
        .order('date', ascending: false);

    return (response as List)
        .map((map) => CarTransaction.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  Future<List<CarTransaction>> getTransactionsByCar(String carId) async {
    _requireAuth();

    // RLS garantiza que solo puedas ver movimientos de tus propios carros
    final response = await SupabaseConfig.client
        .from(_transactionsTable)
        .select()
        .eq('car_id', carId)
        .order('date', ascending: false);

    return (response as List)
        .map((map) => CarTransaction.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateTransaction(CarTransaction transaction) async {
    _requireAuth();

    if (transaction.id == null) {
      throw Exception('No se puede actualizar un movimiento sin ID');
    }

    final updateData = transaction.toMap();
    // Remover id, user_id y car_id del update (no se deben actualizar)
    updateData.remove('id');
    updateData.remove('user_id');
    updateData.remove('car_id');
    updateData['updated_at'] = DateTime.now().toIso8601String();

    await SupabaseConfig.client
        .from(_transactionsTable)
        .update(updateData)
        .eq('id', transaction.id!);
  }

  Future<void> deleteTransaction(String id) async {
    _requireAuth();

    await SupabaseConfig.client
        .from(_transactionsTable)
        .delete()
        .eq('id', id);
  }

  // ============================================
  // GENERACIÓN DE DATOS DE PRUEBA
  // ============================================

  Future<void> generateTestData({bool force = false}) async {
    final userId = _requireAuth();
    
    // Verificar si ya hay datos (a menos que force sea true)
    if (!force) {
      final existingCars = await getAllCars();
      if (existingCars.length >= 10) {
        print('📊 Ya existen ${existingCars.length} carros en la base de datos. No se generarán datos de prueba.');
        print('💡 Para forzar la generación, usa generateTestData(force: true)');
        return;
      } else if (existingCars.isNotEmpty) {
        print('📊 Existen ${existingCars.length} carros. Generando datos adicionales hasta completar 10...');
      }
    } else {
      // Si force es true, eliminar datos existentes primero
      print('🗑️ Eliminando datos existentes...');
      final existingCars = await getAllCars();
      for (final car in existingCars) {
        if (car.id != null) {
          await deleteCar(car.id!);
        }
      }
      print('✅ Datos existentes eliminados');
    }

    print('🔧 Generando datos de prueba...');
    
    final brands = ['Toyota', 'Honda', 'Ford', 'Chevrolet', 'Nissan', 'BMW', 'Mercedes-Benz', 'Audi', 'Volkswagen', 'Hyundai'];
    final models = [
      ['Corolla', 'Camry', 'RAV4', 'Highlander', 'Prius'],
      ['Civic', 'Accord', 'CR-V', 'Pilot', 'HR-V'],
      ['F-150', 'Mustang', 'Explorer', 'Escape', 'Edge'],
      ['Silverado', 'Equinox', 'Tahoe', 'Malibu', 'Traverse'],
      ['Altima', 'Sentra', 'Rogue', 'Pathfinder', 'Murano'],
      ['3 Series', '5 Series', 'X3', 'X5', 'X1'],
      ['C-Class', 'E-Class', 'GLC', 'GLE', 'A-Class'],
      ['A4', 'A6', 'Q5', 'Q7', 'A3'],
      ['Jetta', 'Passat', 'Tiguan', 'Atlas', 'Golf'],
      ['Elantra', 'Sonata', 'Tucson', 'Santa Fe', 'Kona'],
    ];
    final colors = ['Blanco', 'Negro', 'Gris', 'Rojo', 'Azul', 'Plateado', 'Verde'];
    
    final descriptions = [
      'Servicio de taxi',
      'Viaje a aeropuerto',
      'Servicio corporativo',
      'Viaje interurbano',
      'Servicio nocturno',
      'Viaje largo',
      'Servicio express',
      'Viaje compartido',
      'Servicio VIP',
      'Viaje regular',
    ];

    // Obtener carros existentes para saber cuántos faltan
    final existingCars = await getAllCars();
    final existingCount = existingCars.length;
    final carsToGenerate = force ? 10 : (10 - existingCount);
    
    if (carsToGenerate <= 0) {
      print('✅ Ya hay 10 o más carros. No se generarán más.');
      return;
    }
    
    print('📝 Generando $carsToGenerate carros nuevos...');
    final carIds = <String>[];

    // Generar los carros faltantes
    for (int i = existingCount; i < 10; i++) {
      final brand = brands[i];
      final modelList = models[i];
      final model = modelList[i % modelList.length];
      final year = 2015 + (i % 8); // Años entre 2015 y 2022
      final plateNumber = 'ABC${100 + i}';
      final color = colors[i % colors.length];
      final purchaseDate = DateTime(2015 + (i % 8), 1 + (i % 12), 1 + (i % 28));
      final purchasePrice = 15000.0 + (i * 5000.0);

      final car = Car(
        userId: userId,
        brand: brand,
        model: model,
        year: year,
        plateNumber: plateNumber,
        color: color,
        purchaseDate: purchaseDate,
        purchasePrice: purchasePrice,
        notes: i % 3 == 0 ? 'Vehículo en buen estado' : null,
      );

      final carId = await insertCar(car);
      carIds.add(carId);
      print('✅ Carro creado: $brand $model ($year) - ID: $carId');
    }

    // Generar 10 ingresos por cada carro
    for (String carId in carIds) {
      for (int j = 0; j < 10; j++) {
        final baseDate = DateTime.now().subtract(Duration(days: j * 7)); // Últimas 10 semanas
        final description = descriptions[j % descriptions.length];
        final amount = 50000.0 + (j * 10000.0) + (carIds.indexOf(carId) * 1000.0); // Montos variados

        final income = CarTransaction(
          userId: userId,
          carId: carId,
          description: description,
          amount: amount,
          date: baseDate,
          notes: j % 4 == 0 ? 'Ingreso adicional' : null,
        );

        await insertTransaction(income);

        // Un egreso de combustible por cada ingreso, para datos de prueba
        await insertTransaction(
          CarTransaction(
            userId: userId,
            carId: carId,
            type: TransactionType.expense,
            description: 'Tanqueo',
            amount: 30000.0 + (j * 2000.0),
            date: baseDate,
            category: TransactionCategory.fuel,
            liters: 8.0 + j,
          ),
        );
      }
      print('✅ 10 ingresos y 10 egresos creados para carro ID: $carId');
    }

    print('🎉 Datos de prueba generados exitosamente: ${carIds.length} carros y ${carIds.length * 10} ingresos');
    
    // Verificar que los datos se guardaron correctamente
    final verifyCars = await getAllCars();
    final verifyIncomes = await getAllTransactions();
    print('✅ Verificación: ${verifyCars.length} carros y ${verifyIncomes.length} movimientos en la BD');
  }

  // ============================================
  // MÉTODOS PARA ALERTS
  // ============================================

  Future<String> insertAlert(Alert alert) async {
    final userId = _requireAuth();
    
    // Asegurar que el alert tenga el user_id correcto
    final alertData = alert.toMap();
    alertData['user_id'] = userId;
    
    final response = await SupabaseConfig.client
        .from('alerts')
        .insert(alertData)
        .select('id')
        .single();
    
    return response['id'] as String;
  }

  Future<List<Alert>> getAllAlerts() async {
    _requireAuth();
    
    // RLS automáticamente filtra por user_id
    final response = await SupabaseConfig.client
        .from('alerts')
        .select()
        .order('alert_date', ascending: true);
    
    return response
        .map<Alert>((map) => Alert.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<List<Alert>> getAlertsByCar(String carId) async {
    _requireAuth();
    
    // RLS garantiza que solo puedas ver alertas de tus propios carros
    final response = await SupabaseConfig.client
        .from('alerts')
        .select()
        .eq('car_id', carId)
        .order('alert_date', ascending: true);
    
    return response
        .map<Alert>((map) => Alert.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<List<Alert>> getUpcomingAlerts({int days = 7}) async {
    _requireAuth();
    
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    
    // RLS automáticamente filtra por user_id
    final response = await SupabaseConfig.client
        .from('alerts')
        .select()
        .eq('is_completed', false)
        .gte('alert_date', now.toIso8601String())
        .lte('alert_date', endDate.toIso8601String())
        .order('alert_date', ascending: true);
    
    return response
        .map<Alert>((map) => Alert.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<Alert?> getAlert(String id) async {
    _requireAuth();
    
    try {
      final response = await SupabaseConfig.client
          .from('alerts')
          .select()
          .eq('id', id)
          .single();
      
      return Alert.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      // Si no se encuentra la alerta o no pertenece al usuario, RLS retornará error
      return null;
    }
  }

  Future<void> updateAlert(Alert alert) async {
    _requireAuth();
    
    if (alert.id == null) {
      throw Exception('No se puede actualizar una alerta sin ID');
    }
    
    final updateData = alert.toMap();
    // Remover id y user_id del update (no se deben actualizar)
    updateData.remove('id');
    updateData.remove('user_id');
    updateData['updated_at'] = DateTime.now().toIso8601String();
    
    await SupabaseConfig.client
        .from('alerts')
        .update(updateData)
        .eq('id', alert.id!);
  }

  Future<void> deleteAlert(String id) async {
    _requireAuth();
    
    await SupabaseConfig.client
        .from('alerts')
        .delete()
        .eq('id', id);
  }

  Future<void> completeAlert(String id) async {
    _requireAuth();
    
    final now = DateTime.now();
    await SupabaseConfig.client
        .from('alerts')
        .update({
          'is_completed': true,
          'completed_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', id);
  }

  // ============================================
  // MÉTODOS PARA KILOMETRAJE
  // ============================================

  Future<String> insertMileageReading(MileageReading reading) async {
    final userId = _requireAuth();

    final data = reading.toMap();
    data['user_id'] = userId;

    final response = await SupabaseConfig.client
        .from('mileage_readings')
        .insert(data)
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<MileageReading>> getMileageReadingsByCar(String carId) async {
    _requireAuth();

    final response = await SupabaseConfig.client
        .from('mileage_readings')
        .select()
        .eq('car_id', carId)
        .order('reading_date', ascending: false);

    return response
        .map<MileageReading>(
          (map) => MileageReading.fromMap(Map<String, dynamic>.from(map)),
        )
        .toList();
  }

  Future<void> deleteMileageReading(String id) async {
    _requireAuth();

    await SupabaseConfig.client.from('mileage_readings').delete().eq('id', id);
  }

  Future<String> insertMaintenanceLog(MaintenanceLog log) async {
    final userId = _requireAuth();

    final data = log.toMap();
    data['user_id'] = userId;

    final response = await SupabaseConfig.client
        .from('maintenance_logs')
        .insert(data)
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<MaintenanceLog>> getMaintenanceLogsByCar(String carId) async {
    _requireAuth();

    final response = await SupabaseConfig.client
        .from('maintenance_logs')
        .select()
        .eq('car_id', carId)
        .order('service_date', ascending: false);

    return response
        .map<MaintenanceLog>(
          (map) => MaintenanceLog.fromMap(Map<String, dynamic>.from(map)),
        )
        .toList();
  }

  // ============================================
  // MÉTODOS PARA VIAJES GPS
  // ============================================

  Future<String> insertTripLog(TripLog trip) async {
    final userId = _requireAuth();

    final data = trip.toMap();
    data['user_id'] = userId;

    final response = await SupabaseConfig.client
        .from('trip_logs')
        .insert(data)
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<TripLog>> getTripLogsByCar(String carId) async {
    _requireAuth();

    final response = await SupabaseConfig.client
        .from('trip_logs')
        .select()
        .eq('car_id', carId)
        .order('started_at', ascending: false);

    return response
        .map<TripLog>((map) => TripLog.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  // ============================================
  // MÉTODOS DE INICIALIZACIÓN (mantenidos para compatibilidad)
  // ============================================

  Future<void> initialize() async {
    // Ya no hay inicialización de SQLite necesaria
    // Solo verificar que Supabase esté inicializado
    try {
      final userId = _requireAuth();
      print('✅ DatabaseHelper inicializado. Usuario autenticado: $userId');
    } catch (e) {
      print('⚠️ DatabaseHelper inicializado pero sin usuario autenticado. Las operaciones requerirán autenticación.');
    }
  }
}
