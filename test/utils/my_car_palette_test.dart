import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/app_theme.dart';
import 'package:new_my_car_app/utils/my_car_colors.dart';
import 'package:new_my_car_app/utils/my_car_palette.dart';

import '../helpers/contrast.dart';

void main() {
  group('contraste de la paleta oscura', () {
    const dark = MyCarPalette.dark;

    test('el texto es legible sobre tarjetas y fondo de pantalla', () {
      for (final surface in [dark.background, dark.backgroundLight]) {
        expect(contrastRatio(dark.textPrimary, surface), greaterThanOrEqualTo(7));
        expect(contrastRatio(dark.textSecondary, surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(dark.textLabel, surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(dark.textTertiary, surface), greaterThanOrEqualTo(3));
      }
    });

    test('los colores de acento y de estado contrastan', () {
      for (final surface in [dark.background, dark.backgroundLight]) {
        expect(contrastRatio(dark.accent, surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(dark.income, surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(dark.expense, surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(MyCarColors.error, surface), greaterThanOrEqualTo(3));
        expect(contrastRatio(MyCarColors.success, surface), greaterThanOrEqualTo(4.5));
      }
    });

    test('el texto sobre los tintes de marca es legible', () {
      for (final tint in [dark.primaryLight, dark.primarySoft, dark.secondaryLight]) {
        expect(contrastRatio(dark.textPrimary, tint), greaterThanOrEqualTo(7));
      }
      expect(contrastRatio(dark.income, dark.incomeLight), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(dark.expense, dark.expenseLight), greaterThanOrEqualTo(3));
    });

    test('los bordes se distinguen del fondo de pantalla', () {
      expect(contrastRatio(dark.border, dark.backgroundLight), greaterThan(1.2));
    });
  });

  group('contraste de la paleta clara', () {
    const light = MyCarPalette.light;

    test('el texto sigue siendo legible', () {
      expect(contrastRatio(light.textPrimary, light.background), greaterThanOrEqualTo(7));
      expect(contrastRatio(light.textSecondary, light.background), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(light.textLabel, light.background), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(light.accent, light.background), greaterThanOrEqualTo(4.5));
    });
  });

  test('la paleta oscura invierte la clara en lo esencial', () {
    expect(MyCarPalette.dark.background, isNot(MyCarPalette.light.background));
    expect(MyCarPalette.dark.textPrimary, isNot(MyCarPalette.light.textPrimary));
    expect(
      MyCarPalette.dark.textPrimary.computeLuminance(),
      greaterThan(MyCarPalette.dark.background.computeLuminance()),
    );
    expect(
      MyCarPalette.light.textPrimary.computeLuminance(),
      lessThan(MyCarPalette.light.background.computeLuminance()),
    );
  });

  test('lerp interpola y copyWith reemplaza', () {
    final half = MyCarPalette.light.lerp(MyCarPalette.dark, 0.5);
    expect(half.background, Color.lerp(
      MyCarPalette.light.background,
      MyCarPalette.dark.background,
      0.5,
    ));
    expect(MyCarPalette.light.lerp(null, 0.5), MyCarPalette.light);
    expect(
      MyCarPalette.light.copyWith(textPrimary: Colors.red).textPrimary,
      Colors.red,
    );
  });

  group('tema', () {
    testWidgets('cada tema expone su paleta', (tester) async {
      MyCarPalette? seen;
      Future<void> pumpWith(ThemeData theme) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                seen = context.palette;
                return const SizedBox();
              },
            ),
          ),
        );
      }

      await pumpWith(AppTheme.lightTheme);
      expect(seen!.background, MyCarPalette.light.background);
      expect(seen!.textPrimary, MyCarPalette.light.textPrimary);
      await pumpWith(AppTheme.darkTheme);
      await tester.pumpAndSettle();
      expect(seen!.background, MyCarPalette.dark.background);
      expect(seen!.textPrimary, MyCarPalette.dark.textPrimary);
    });

    testWidgets('sin AppTheme se usa la paleta clara', (tester) async {
      MyCarPalette? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen!.background, MyCarPalette.light.background);
      expect(seen!.textPrimary, MyCarPalette.light.textPrimary);
    });

    test('el tema oscuro alinea fondo y superficies con la paleta', () {
      final theme = AppTheme.darkTheme;
      const dark = MyCarPalette.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, dark.backgroundLight);
      expect(theme.colorScheme.surface, dark.backgroundLight);
      expect(theme.colorScheme.onSurface, dark.textPrimary);
      expect(theme.dialogTheme.backgroundColor, dark.background);
      expect(theme.bottomSheetTheme.backgroundColor, dark.background);
      expect(theme.cardTheme.color, dark.background);
    });

    test('el tema claro no cambió', () {
      final theme = AppTheme.lightTheme;

      expect(theme.scaffoldBackgroundColor, MyCarColors.backgroundLight);
      expect(theme.dialogTheme.backgroundColor, MyCarPalette.light.background);
    });
  });

  // Regla de arquitectura: las pantallas no usan colores que dependen del
  // fondo directamente (se ven mal en modo oscuro). Se leen con
  // `context.palette`.
  test('las pantallas no usan colores estáticos que dependen del fondo', () {
    // `\s*` porque el formateador puede partir `MyCarColors` y `.token` en dos
    // líneas.
    final forbidden = RegExp(
      r'MyCarColors\s*\.\s*(textPrimary|textSecondary|textTertiary|textLabel|'
      r'border|borderLight|background|backgroundLight|surfaceMuted|'
      r'primaryLight|secondaryLight|incomeLight|expenseLight|income|expense|'
      r'indigo50|indigo100|gray\d+)\b',
    );
    final allowed = {
      'my_car_colors.dart',
      'my_car_palette.dart',
      'app_theme.dart',
    };

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed.contains(entity.uri.pathSegments.last)) continue;
      final source = entity.readAsStringSync();
      final lines = source.split('\n');
      String lineAt(int offset) {
        final line = '\n'.allMatches(source.substring(0, offset)).length;
        return '${entity.path}:${line + 1}  ${lines[line].trim()}';
      }

      for (final match in forbidden.allMatches(source)) {
        final line = lineAt(match.start);
        if (!line.contains('//')) offenders.add(line);
      }
      for (final match in RegExp(r'Colors\.grey\[').allMatches(source)) {
        offenders.add(lineAt(match.start));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Usa context.palette.<color> en vez de MyCarColors.<color> '
          '(ver skill ui-system):\n${offenders.join('\n')}',
    );
  });
}
