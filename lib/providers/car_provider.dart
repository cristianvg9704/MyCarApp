import 'package:flutter/material.dart';
import '../models/car.dart';
import '../services/database_helper.dart';

class CarProvider extends ChangeNotifier {
  /// [fetchCars] permite sustituir el acceso a datos (por defecto Supabase a
  /// través de [DatabaseHelper]) para poder probar la carga sin backend.
  CarProvider({Future<List<Car>> Function()? fetchCars})
    : _fetchCars = fetchCars;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Future<List<Car>> Function()? _fetchCars;
  List<Car> _cars = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<Car> get cars => _cars;
  bool get isLoading => _isLoading;

  /// Verdadero cuando ya terminó al menos una carga (con o sin error).
  ///
  /// Distingue "aún no he cargado" de "cargué y no hay vehículos": una lista
  /// vacía por sí sola no significa que falte cargar. Las pantallas deben
  /// usarlo (y no `cars.isEmpty`) para decidir si piden la carga inicial.
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  Future<void> loadCars() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _cars = await (_fetchCars?.call() ?? _dbHelper.getAllCars());
    } catch (e) {
      debugPrint('Error loading cars: $e');
      _errorMessage = 'No se pudieron cargar tus vehículos. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
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
