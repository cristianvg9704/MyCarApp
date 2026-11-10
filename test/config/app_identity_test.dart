import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Nombre con el que la app aparece bajo el ícono en el teléfono.
const appDisplayName = 'MyCar App';

void main() {
  test('iOS muestra "$appDisplayName" bajo el ícono', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    final match = RegExp(
      r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>',
    ).firstMatch(plist);

    expect(match, isNotNull);
    expect(match!.group(1), appDisplayName);
  });

  test('Android muestra "$appDisplayName" bajo el ícono', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    final match = RegExp(r'<application[^>]*android:label="([^"]*)"')
        .firstMatch(manifest);

    expect(match, isNotNull);
    expect(match!.group(1), appDisplayName);
  });
}
