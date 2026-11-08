import '../config/supabase_config.dart';
import '../models/car_transaction.dart';
import '../models/maintenance_log.dart';
import '../models/mileage_reading.dart';
import 'database_helper.dart';

/// Acceso a los datos que alimentan kilometraje y recomendaciones.
/// Abstracción para poder probar el provider sin Supabase.
abstract class MileageRepository {
  String? get currentUserId;
  Future<List<MileageReading>> getReadings(String carId);
  Future<List<MaintenanceLog>> getMaintenanceLogs(String carId);
  Future<List<CarTransaction>> getTransactions(String carId);
  Future<void> addReading(MileageReading reading);
  Future<void> addMaintenanceLog(MaintenanceLog log);
}

class SupabaseMileageRepository implements MileageRepository {
  final DatabaseHelper _db;

  SupabaseMileageRepository([DatabaseHelper? db])
    : _db = db ?? DatabaseHelper.instance;

  @override
  String? get currentUserId => SupabaseConfig.client.auth.currentUser?.id;

  @override
  Future<List<MileageReading>> getReadings(String carId) =>
      _db.getMileageReadingsByCar(carId);

  @override
  Future<List<MaintenanceLog>> getMaintenanceLogs(String carId) =>
      _db.getMaintenanceLogsByCar(carId);

  @override
  Future<List<CarTransaction>> getTransactions(String carId) =>
      _db.getTransactionsByCar(carId);

  @override
  Future<void> addReading(MileageReading reading) =>
      _db.insertMileageReading(reading);

  @override
  Future<void> addMaintenanceLog(MaintenanceLog log) =>
      _db.insertMaintenanceLog(log);
}
