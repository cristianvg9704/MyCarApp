import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/app_logging.dart';

void main() {
  late DebugPrintCallback original;
  late List<String?> printed;

  setUp(() {
    original = debugPrint;
    printed = [];
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
  });

  tearDown(() => debugPrint = original);

  test('en release descarta los logs de debugPrint', () {
    configureLogging(isRelease: true);

    debugPrint('secreto');

    expect(printed, isEmpty);
  });

  test('en debug no toca debugPrint', () {
    configureLogging(isRelease: false);

    debugPrint('visible');

    expect(printed, ['visible']);
  });
}
