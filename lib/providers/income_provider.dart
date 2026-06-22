import 'package:flutter/material.dart';
import '../models/income.dart';
import '../services/database_helper.dart';

class IncomeProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Income> _incomes = [];
  bool _isLoading = false;
  String? _selectedCarId;

  List<Income> get incomes => _incomes;
  bool get isLoading => _isLoading;
  String? get selectedCarId => _selectedCarId;

  Future<void> loadIncomesByCar(String carId) async {
    _selectedCarId = carId;
    _isLoading = true;
    notifyListeners();

    try {
      _incomes = await _dbHelper.getIncomesByCar(carId);
    } catch (e) {
      debugPrint('Error loading incomes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addIncome(Income income) async {
    try {
      await _dbHelper.insertIncome(income);
      if (_selectedCarId != null) {
        await loadIncomesByCar(_selectedCarId!);
      }
    } catch (e) {
      debugPrint('Error adding income: $e');
      rethrow;
    }
  }

  Future<void> updateIncome(Income income) async {
    try {
      await _dbHelper.updateIncome(income);
      if (_selectedCarId != null) {
        await loadIncomesByCar(_selectedCarId!);
      }
    } catch (e) {
      debugPrint('Error updating income: $e');
      rethrow;
    }
  }

  Future<void> deleteIncome(String id) async {
    try {
      await _dbHelper.deleteIncome(id);
      if (_selectedCarId != null) {
        await loadIncomesByCar(_selectedCarId!);
      }
    } catch (e) {
      debugPrint('Error deleting income: $e');
      rethrow;
    }
  }
}
