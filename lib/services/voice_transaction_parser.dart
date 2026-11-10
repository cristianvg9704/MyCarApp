import '../models/car_transaction.dart';
import '../utils/spanish_number_parser.dart';

/// Movimiento interpretado a partir de lo que dijo el usuario. No se guarda
/// directamente: se vuelca en el formulario para que el usuario lo confirme.
class VoiceTransactionDraft {
  final String transcript;
  final TransactionType type;
  final TransactionCategory? category;
  final double? amount;
  final String description;
  final DateTime date;
  final double? liters;
  final double? odometerKm;

  const VoiceTransactionDraft({
    required this.transcript,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    this.liters,
    this.odometerKm,
  });

  bool get hasAmount => amount != null;

  /// Movimiento listo para guardar. Requiere [hasAmount].
  ///
  /// Litros solo en combustible y kilometraje solo en combustible/mantenimiento
  /// (igual que el formulario). Sin descripción usa el nombre de la categoría.
  CarTransaction toTransaction({
    required String userId,
    required String carId,
  }) {
    assert(hasAmount, 'No se puede guardar un movimiento sin monto');
    final isExpense = type == TransactionType.expense;
    final expenseCategory = isExpense
        ? (category ?? TransactionCategory.other)
        : null;
    final isFuel = expenseCategory == TransactionCategory.fuel;
    final isMaintenance = expenseCategory == TransactionCategory.maintenance;
    final text = description.trim();
    return CarTransaction(
      userId: userId,
      carId: carId,
      type: type,
      description: text.isEmpty ? (expenseCategory?.label ?? type.label) : text,
      amount: amount!,
      date: date,
      category: expenseCategory,
      liters: isFuel ? liters : null,
      odometerKm: isFuel || isMaintenance ? odometerKm : null,
    );
  }
}

/// Interpreta frases en español (Colombia) como "gasté cincuenta mil en
/// gasolina ayer" o "me pagaron 120.000 por una carrera". Es lógica pura, sin
/// IA ni red; si el reconocimiento más adelante usa un modelo, esta clase
/// sigue siendo el respaldo sin conexión.
class VoiceTransactionParser {
  VoiceTransactionParser._();

  static const double _litersPerGallon = 3.785;

  static const _strongExpense = {
    'gaste',
    'gasto',
    'gastamos',
    'gastos',
    'egreso',
    'egrese',
    'pague',
    'pagamos',
    'compre',
    'compramos',
    'tanquee',
    'tanqueamos',
    'eche',
    'echamos',
    'repare',
    'arregle',
    'cambie',
    'cambiamos',
    'inverti',
    'invertimos',
    'abaste',
    'abastecimos',
    'lave',
  };

  static const _strongIncome = {
    'ingreso',
    'ingrese',
    'ingresaron',
    'ingresamos',
    'gane',
    'ganamos',
    'ganancia',
    'cobre',
    'cobramos',
    'cobro',
    'recibi',
    'recibimos',
    'pagaron',
    'vendi',
    'vendimos',
    'facture',
  };

  static const _fuelWords = {
    'gasolina',
    'combustible',
    'tanqueo',
    'tanqueos',
    'tanquee',
    'tanqueamos',
    'tanquear',
    'acpm',
    'diesel',
    'gas',
    'galon',
    'galones',
    'litro',
    'litros',
    'abaste',
    'abastecimos',
    'tanque',
  };

  static const _maintenanceWords = {
    'aceite',
    'mantenimiento',
    'mecanico',
    'taller',
    'llanta',
    'llantas',
    'neumatico',
    'neumaticos',
    'freno',
    'frenos',
    'filtro',
    'filtros',
    'revision',
    'alineacion',
    'balanceo',
    'bateria',
    'repuesto',
    'repuestos',
    'reparacion',
    'repare',
    'arregle',
    'sincronizacion',
    'lubricacion',
    'mantenimientos',
    'pastillas',
    'correa',
    'amortiguadores',
    'bujias',
  };

  static const _otherExpenseWords = {
    'peaje',
    'peajes',
    'parqueadero',
    'parqueo',
    'lavado',
    'lave',
    'multa',
    'comparendo',
    'seguro',
    'soat',
    'tecnomecanica',
    'impuesto',
  };

  static const _litersUnits = {'litro', 'litros', 'lt', 'lts'};
  static const _gallonUnits = {'galon', 'galones'};
  static const _kmUnits = {'km', 'kms', 'kilometro', 'kilometros'};
  static const _odometerWords = {'kilometraje', 'odometro'};
  static const _moneyMarkersAfter = {'pesos', 'cop', 'peso'};

  static const _months = {
    'enero': 1,
    'febrero': 2,
    'marzo': 3,
    'abril': 4,
    'mayo': 5,
    'junio': 6,
    'julio': 7,
    'agosto': 8,
    'septiembre': 9,
    'setiembre': 9,
    'octubre': 10,
    'noviembre': 11,
    'diciembre': 12,
  };

  static const _weekdays = {
    'lunes': DateTime.monday,
    'martes': DateTime.tuesday,
    'miercoles': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'viernes': DateTime.friday,
    'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };

  /// [defaultType] se usa cuando la frase no deja claro si es ingreso o egreso.
  static VoiceTransactionDraft parse(
    String transcript, {
    DateTime? now,
    TransactionType defaultType = TransactionType.income,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final tokens = tokenizeSpanish(transcript);
    final numbers = extractSpokenNumbers(tokens);
    final claimed = <SpokenNumber>{};

    double? liters;
    double? odometerKm;
    DateTime? date;

    String? tokenAt(int index) =>
        index >= 0 && index < tokens.length ? tokens[index] : null;

    for (final number in numbers) {
      final before = tokenAt(number.start - 1);
      final before2 = tokenAt(number.start - 2);
      final after = tokenAt(number.end);
      final after2 = tokenAt(number.end + 1);

      // "hace 3 días", "hace una semana"
      if (before == 'hace' && after != null) {
        if (after.startsWith('dia')) {
          date ??= today.subtract(Duration(days: number.value.round()));
          claimed.add(number);
          continue;
        }
        if (after.startsWith('semana')) {
          date ??= today.subtract(Duration(days: 7 * number.value.round()));
          claimed.add(number);
          continue;
        }
      }

      // "el 15 de octubre"
      if (after == 'de' && after2 != null && _months.containsKey(after2)) {
        final day = number.value.round();
        if (day >= 1 && day <= 31) {
          date ??= _dateFromDayMonth(day, _months[after2]!, today);
          claimed.add(number);
          continue;
        }
      }

      if (after != null && _litersUnits.contains(after)) {
        liters ??= number.value;
        claimed.add(number);
        continue;
      }
      if (after != null && _gallonUnits.contains(after)) {
        liters ??= double.parse(
          (number.value * _litersPerGallon).toStringAsFixed(2),
        );
        claimed.add(number);
        continue;
      }

      if ((after != null && _kmUnits.contains(after)) ||
          (before != null && _odometerWords.contains(before)) ||
          (before2 != null &&
              _odometerWords.contains(before2) &&
              (before == 'de' || before == 'en' || before == 'a'))) {
        odometerKm ??= number.value;
        claimed.add(number);
      }
    }

    final amount = _pickAmount(tokens, numbers, claimed);
    date ??= _dateFromWords(tokens, today) ?? today;

    final type = _resolveType(tokens, defaultType);
    final category = type == TransactionType.expense
        ? _resolveCategory(tokens, liters != null)
        : null;

    return VoiceTransactionDraft(
      transcript: transcript.trim(),
      type: type,
      category: category,
      amount: amount,
      description: _describe(transcript, type, category),
      date: date,
      liters: category == TransactionCategory.fuel ? liters : null,
      odometerKm:
          category == TransactionCategory.fuel ||
              category == TransactionCategory.maintenance
          ? odometerKm
          : null,
    );
  }

  static double? _pickAmount(
    List<String> tokens,
    List<SpokenNumber> numbers,
    Set<SpokenNumber> claimed,
  ) {
    final candidates = numbers
        .where((n) => !claimed.contains(n) && !n.isArticle && n.value > 0)
        .toList();
    if (candidates.isEmpty) return null;

    for (final n in candidates) {
      final before = n.start > 0 ? tokens[n.start - 1] : null;
      final after = n.end < tokens.length ? tokens[n.end] : null;
      if (before == r'$' ||
          (after != null && _moneyMarkersAfter.contains(after))) {
        return n.value;
      }
    }
    return candidates.map((n) => n.value).reduce((a, b) => a > b ? a : b);
  }

  static TransactionType _resolveType(
    List<String> tokens,
    TransactionType defaultType,
  ) {
    int? firstIndex(Set<String> words) {
      final index = tokens.indexWhere(words.contains);
      return index < 0 ? null : index;
    }

    final expense = firstIndex(_strongExpense);
    final income = firstIndex(_strongIncome);

    if (expense != null && income == null) return TransactionType.expense;
    if (income != null && expense == null) return TransactionType.income;
    if (expense != null && income != null) {
      return income < expense
          ? TransactionType.income
          : TransactionType.expense;
    }

    final hasCategoryWord = tokens.any(
      (t) =>
          _fuelWords.contains(t) ||
          _maintenanceWords.contains(t) ||
          _otherExpenseWords.contains(t),
    );
    return hasCategoryWord ? TransactionType.expense : defaultType;
  }

  static TransactionCategory _resolveCategory(
    List<String> tokens,
    bool hasLiters,
  ) {
    for (final token in tokens) {
      if (_maintenanceWords.contains(token)) {
        return TransactionCategory.maintenance;
      }
      if (_fuelWords.contains(token)) return TransactionCategory.fuel;
      if (_otherExpenseWords.contains(token)) return TransactionCategory.other;
    }
    return hasLiters ? TransactionCategory.fuel : TransactionCategory.other;
  }

  static DateTime? _dateFromWords(List<String> tokens, DateTime today) {
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == 'hoy') return today;
      if (token == 'ayer') {
        final twoBefore =
            i >= 2 && tokens[i - 2] == 'antes' && tokens[i - 1] == 'de';
        return today.subtract(Duration(days: twoBefore ? 2 : 1));
      }
      if (token == 'anteayer' || token == 'antier' || token == 'antiayer') {
        return today.subtract(const Duration(days: 2));
      }
      final weekday = _weekdays[token];
      if (weekday != null) {
        var diff = (today.weekday - weekday) % 7;
        if (diff == 0) diff = 7;
        return today.subtract(Duration(days: diff));
      }
    }
    return null;
  }

  static DateTime _dateFromDayMonth(int day, int month, DateTime today) {
    var candidate = DateTime(today.year, month, day);
    if (candidate.isAfter(today)) {
      candidate = DateTime(today.year - 1, month, day);
    }
    return candidate;
  }

  static String _describe(
    String transcript,
    TransactionType type,
    TransactionCategory? category,
  ) {
    if (type == TransactionType.expense &&
        (category == TransactionCategory.fuel ||
            category == TransactionCategory.maintenance)) {
      return category!.label;
    }
    final text = transcript.trim();
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}
