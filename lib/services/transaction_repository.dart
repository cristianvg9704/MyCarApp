import '../models/car_transaction.dart';
import 'database_helper.dart';

/// Acceso a datos de movimientos. Abstracción para poder probar providers y
/// pantallas sin Supabase.
abstract class TransactionRepository {
  Future<List<CarTransaction>> getByCar(String carId);
  Future<String> add(CarTransaction transaction);
  Future<void> update(CarTransaction transaction);
  Future<void> delete(String id);
}

class SupabaseTransactionRepository implements TransactionRepository {
  final DatabaseHelper _db;

  SupabaseTransactionRepository([DatabaseHelper? db])
    : _db = db ?? DatabaseHelper.instance;

  @override
  Future<List<CarTransaction>> getByCar(String carId) =>
      _db.getTransactionsByCar(carId);

  @override
  Future<String> add(CarTransaction transaction) =>
      _db.insertTransaction(transaction);

  @override
  Future<void> update(CarTransaction transaction) =>
      _db.updateTransaction(transaction);

  @override
  Future<void> delete(String id) => _db.deleteTransaction(id);
}
