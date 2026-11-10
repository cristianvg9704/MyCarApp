/// Quita los `null` de cada fila (para que apliquen los DEFAULT de la base de
/// datos) y agrupa las filas por su conjunto de claves.
///
/// PostgREST exige que todos los objetos de un insert por lotes tengan las
/// mismas claves ("All object keys must match"), así que cada grupo se envía en
/// su propia petición.
List<List<Map<String, dynamic>>> groupRowsByKeys(
  Iterable<Map<String, dynamic>> rows,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final cleaned = <String, dynamic>{
      for (final e in row.entries)
        if (e.value != null) e.key: e.value,
    };
    final signature = (cleaned.keys.toList()..sort()).join(',');
    groups.putIfAbsent(signature, () => []).add(cleaned);
  }
  return groups.values.toList();
}
