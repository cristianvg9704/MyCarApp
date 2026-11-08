import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/widgets/config_error_app.dart';

void main() {
  testWidgets('names the missing variables and the command to run', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigErrorApp(missing: ['SUPABASE_URL', 'SUPABASE_ANON_KEY']),
    );

    expect(find.text('Falta configuración'), findsOneWidget);
    expect(find.text('SUPABASE_URL'), findsOneWidget);
    expect(find.text('SUPABASE_ANON_KEY'), findsOneWidget);
    expect(find.text(ConfigErrorApp.runCommand), findsOneWidget);
    expect(ConfigErrorApp.runCommand, contains('--dart-define-from-file=.env'));
  });
}
