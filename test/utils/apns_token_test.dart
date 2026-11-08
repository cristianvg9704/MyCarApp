import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/apns_token.dart';

void main() {
  const noWait = Duration.zero;

  test('returns the token right away when it is already available', () async {
    var calls = 0;

    final token = await waitForApnsToken(() async {
      calls++;
      return 'abc123';
    }, interval: noWait);

    expect(token, 'abc123');
    expect(calls, 1);
  });

  test('retries until the token arrives', () async {
    var calls = 0;

    final token = await waitForApnsToken(() async {
      calls++;
      return calls < 4 ? null : 'late-token';
    }, interval: noWait);

    expect(token, 'late-token');
    expect(calls, 4);
  });

  test('treats an empty token as missing', () async {
    var calls = 0;

    final token = await waitForApnsToken(() async {
      calls++;
      return calls < 2 ? '' : 'ok';
    }, interval: noWait);

    expect(token, 'ok');
    expect(calls, 2);
  });

  test('gives up with null after the maximum attempts', () async {
    var calls = 0;

    final token = await waitForApnsToken(
      () async {
        calls++;
        return null;
      },
      attempts: 5,
      interval: noWait,
    );

    expect(token, isNull);
    expect(calls, 5);
  });

  test(
    'waits the interval between attempts but not after the last one',
    () async {
      final stopwatch = Stopwatch()..start();

      await waitForApnsToken(
        () async => null,
        attempts: 3,
        interval: const Duration(milliseconds: 50),
      );

      // 2 esperas de 50 ms (no hay espera tras el último intento)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(95));
      expect(stopwatch.elapsedMilliseconds, lessThan(400));
    },
  );
}
