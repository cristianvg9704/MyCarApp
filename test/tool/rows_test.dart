import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed/demo_data_generator.dart';
import '../../tool/seed/rows.dart';

void main() {
  test('quita los null y agrupa las filas por sus claves', () {
    final groups = groupRowsByKeys([
      {'id': '1', 'notes': 'a', 'color': null},
      {'id': '2', 'notes': null, 'color': null},
      {'id': '3', 'notes': 'b', 'color': null},
    ]);

    expect(groups, hasLength(2));
    for (final group in groups) {
      final keys = group.first.keys.toSet();
      expect(
        group.every(
          (row) =>
              row.keys.toSet().containsAll(keys) && row.length == keys.length,
        ),
        isTrue,
      );
      expect(group.expand((row) => row.values).contains(null), isFalse);
    }
    expect(groups.expand((g) => g).length, 3);
  });

  test('los datos de demo generan lotes con claves homogéneas', () {
    var n = 0;
    final data = DemoDataGenerator(
      userId: 'u',
      now: DateTime(2026, 11, 9),
      newId: () => 'id-${n++}',
    ).generate();

    final tables = {
      'cars': data.cars.map((e) => e.toMap()),
      'mileage': data.mileageReadings.map((e) => e.toMap()),
      'logs': data.maintenanceLogs.map((e) => e.toMap()),
      'transactions': data.transactions.map((e) => e.toMap()),
      'trips': data.trips.map((e) => e.toMap()),
      'alerts': data.alerts.map((e) => e.toMap()),
    };
    for (final entry in tables.entries) {
      final groups = groupRowsByKeys(entry.value);
      expect(
        groups.expand((g) => g).length,
        entry.value.length,
        reason: entry.key,
      );
      for (final group in groups) {
        final keys = group.first.keys.toSet();
        expect(
          group.every(
            (r) =>
                r.keys.toSet().length == keys.length &&
                r.keys.toSet().containsAll(keys),
          ),
          isTrue,
          reason: entry.key,
        );
      }
    }
  });
}
