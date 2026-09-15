import 'package:flutter/material.dart';
import '../models/car.dart';
import '../services/database_helper.dart';

class CarProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Car> _cars = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Car> get cars => _cars;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCars() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _cars = await _dbHelper.getAllCars();
    } catch (e) {
      debugPrint('Error loading cars: $e');
      _errorMessage = 'No se pudieron cargar tus vehículos. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCar(Car car) async {
    try {
      await _dbHelper.insertCar(car);
      await loadCars();
    } catch (e) {
      debugPrint('Error adding car: $e');
      rethrow;
    }
  }

  Future<void> updateCar(Car car) async {
    try {
      await _dbHelper.updateCar(car);
      await loadCars();
    } catch (e) {
      debugPrint('Error updating car: $e');
      rethrow;
    }
  }

  Future<void> deleteCar(String id) async {
    try {
      await _dbHelper.deleteCar(id);
      await loadCars();
    } catch (e) {
      debugPrint('Error deleting car: $e');
      rethrow;
    }
  }
}
