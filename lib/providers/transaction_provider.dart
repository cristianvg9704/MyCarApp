import 'package:flutter/material.dart';
import '../models/car_transaction.dart';
import '../services/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository;
  List<CarTransaction> _transactions = [];
  bool _isLoading = false;
  String? _selectedCarId;

  TransactionProvider({TransactionRepository? repository})
    : _repository = repository ?? SupabaseTransactionRepository();

  List<CarTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get selectedCarId => _selectedCarId;

  Future<void> loadByCar(String carId) async {
    _selectedCarId = carId;
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _repository.getByCar(carId);
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add(CarTransaction transaction) =>
      _mutate('adding', () => _repository.add(transaction));

  Future<void> update(CarTransaction transaction) =>
      _mutate('updating', () => _repository.update(transaction));

  Future<void> delete(String id) =>
      _mutate('deleting', () => _repository.delete(id));

  /// Ejecuta una escritura y recarga la lista del vehículo seleccionado.
  Future<void> _mutate(String action, Future<void> Function() write) async {
    try {
      await write();
      final carId = _selectedCarId;
      if (carId != null) await loadByCar(carId);
    } catch (e) {
      debugPrint('Error $action transaction: $e');
      rethrow;
    }
  }
}
