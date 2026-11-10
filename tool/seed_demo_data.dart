// Carga datos de demostración en la cuenta de un usuario de Supabase.
//
// Inicia sesión con el correo y la contraseña (como lo hace la app) y inserta
// por la API REST con ese token, así que respeta RLS y no necesita la clave
// service_role. Es idempotente: antes de insertar borra los vehículos de demo
// (por placa) de ese usuario, y con ellos todo su historial (ON DELETE CASCADE).
// No toca los demás vehículos de la cuenta.
//
// Uso (desde la raíz del proyecto):
//   dart run tool/seed_demo_data.dart --email tu@correo.com --password '...'
//   dart run tool/seed_demo_data.dart --email tu@correo.com --password '...' --reset
//
// También acepta SEED_EMAIL y SEED_PASSWORD como variables de entorno, y
// --env para indicar otro archivo (por defecto `.env`, con SUPABASE_URL y
// SUPABASE_ANON_KEY).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'seed/demo_data_generator.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options == null) {
    _printUsage();
    exit(64);
  }

  final env = _readEnvFile(options.envPath);
  final url = (env['SUPABASE_URL'] ?? '').replaceAll(RegExp(r'/+$'), '');
  final anonKey = env['SUPABASE_ANON_KEY'] ?? '';
  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln(
      'Faltan SUPABASE_URL / SUPABASE_ANON_KEY en ${options.envPath}.',
    );
    exit(78);
  }

  final client = _Supabase(url: url, anonKey: anonKey);
  try {
    stdout.writeln('Iniciando sesión como ${options.email}...');
    final session = await client.signIn(options.email, options.password);

    final removed = await client.deleteDemoCars(
      session,
      DemoDataGenerator.demoPlates,
    );
    stdout.writeln('Vehículos de demo anteriores eliminados: $removed');
    if (options.resetOnly) {
      stdout.writeln('Listo (solo --reset: no se insertó nada).');
      return;
    }

    final data = DemoDataGenerator(
      userId: session.userId,
      now: DateTime.now(),
      newId: _uuidV4,
    ).generate();

    await client.insert(session, 'cars', data.cars.map((e) => e.toMap()));
    await client.insert(
      session,
      'mileage_readings',
      data.mileageReadings.map((e) => e.toMap()),
    );
    await client.insert(
      session,
      'maintenance_logs',
      data.maintenanceLogs.map((e) => e.toMap()),
    );
    await client.insert(
      session,
      'car_transactions',
      data.transactions.map((e) => e.toMap()),
    );
    await client.insert(session, 'trip_logs', data.trips.map((e) => e.toMap()));
    await client.insert(session, 'alerts', data.alerts.map((e) => e.toMap()));

    stdout.writeln('''

Datos de demo creados:
  Vehículos:            ${data.cars.length}
  Lecturas de odómetro: ${data.mileageReadings.length}
  Servicios:            ${data.maintenanceLogs.length}
  Movimientos:          ${data.transactions.length}
  Viajes:               ${data.trips.length}
  Alertas:              ${data.alerts.length}
''');
  } on _SeedException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } finally {
    client.close();
  }
}

class _Options {
  final String email;
  final String password;
  final String envPath;
  final bool resetOnly;

  const _Options(this.email, this.password, this.envPath, this.resetOnly);

  static _Options? parse(List<String> args) {
    String? email = Platform.environment['SEED_EMAIL'];
    String? password = Platform.environment['SEED_PASSWORD'];
    var envPath = '.env';
    var resetOnly = false;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--email':
          if (++i >= args.length) return null;
          email = args[i];
        case '--password':
          if (++i >= args.length) return null;
          password = args[i];
        case '--env':
          if (++i >= args.length) return null;
          envPath = args[i];
        case '--reset':
          resetOnly = true;
        default:
          return null;
      }
    }
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return _Options(email, password, envPath, resetOnly);
  }
}

void _printUsage() {
  stderr.writeln('''
Uso: dart run tool/seed_demo_data.dart --email <correo> --password <clave> [--env .env] [--reset]

  --reset   solo borra los vehículos de demo (no inserta datos nuevos)

También se puede usar SEED_EMAIL y SEED_PASSWORD como variables de entorno.''');
}

/// Lee un archivo `.env` simple (CLAVE=valor, # comentarios).
Map<String, String> _readEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('No se encontró $path (copia .env.example y rellénalo).');
    exit(78);
  }
  final result = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    result[line.substring(0, eq).trim()] = value;
  }
  return result;
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _SeedException implements Exception {
  final String message;
  const _SeedException(this.message);
}

class _Session {
  final String accessToken;
  final String userId;
  const _Session(this.accessToken, this.userId);
}

/// Cliente mínimo de Supabase (Auth + PostgREST) sobre `package:http`.
class _Supabase {
  final String url;
  final String anonKey;
  final http.Client _http = http.Client();

  _Supabase({required this.url, required this.anonKey});

  void close() => _http.close();

  Future<_Session> signIn(String email, String password) async {
    final response = await _http.post(
      Uri.parse('$url/auth/v1/token?grant_type=password'),
      headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw _SeedException(
        'No se pudo iniciar sesión (${response.statusCode}): ${response.body}\n'
        'Revisa el correo/clave y que el correo esté confirmado en Supabase.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _Session(
      body['access_token'] as String,
      (body['user'] as Map<String, dynamic>)['id'] as String,
    );
  }

  Map<String, String> _rest(_Session session, {String? prefer}) => {
    'apikey': anonKey,
    'Authorization': 'Bearer ${session.accessToken}',
    'Content-Type': 'application/json',
    if (prefer != null) 'Prefer': prefer,
  };

  /// Borra los vehículos con esas placas del usuario. Devuelve cuántos.
  Future<int> deleteDemoCars(_Session session, List<String> plates) async {
    final uri = Uri.parse('$url/rest/v1/cars').replace(
      queryParameters: {
        'user_id': 'eq.${session.userId}',
        'plate_number': 'in.(${plates.join(',')})',
        'select': 'id',
      },
    );
    final response = await _http.delete(
      uri,
      headers: _rest(session, prefer: 'return=representation'),
    );
    if (response.statusCode >= 300) {
      throw _SeedException(
        'No se pudieron borrar los vehículos de demo '
        '(${response.statusCode}): ${response.body}',
      );
    }
    return (jsonDecode(response.body) as List).length;
  }

  Future<void> insert(
    _Session session,
    String table,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    // Se omiten los null para que apliquen los DEFAULT de la base de datos.
    final cleaned = [
      for (final row in rows)
        {
          for (final e in row.entries)
            if (e.value != null) e.key: e.value,
        },
    ];
    const chunkSize = 200;
    for (var i = 0; i < cleaned.length; i += chunkSize) {
      final chunk = cleaned.sublist(i, min(i + chunkSize, cleaned.length));
      final response = await _http.post(
        Uri.parse('$url/rest/v1/$table'),
        headers: _rest(session, prefer: 'return=minimal'),
        body: jsonEncode(chunk),
      );
      if (response.statusCode >= 300) {
        throw _SeedException(
          'Falló el insert en $table (${response.statusCode}): '
          '${response.body}',
        );
      }
    }
    stdout.writeln('  $table: ${cleaned.length} filas');
  }
}
