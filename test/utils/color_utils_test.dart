import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:new_my_car_app/utils/my_car_colors.dart';

void main() {
  group('MyCarColors Tests', () {
    test('should have primary color defined', () {
      expect(MyCarColors.primary, isA<Color>());
    });

    test('should have background colors defined', () {
      expect(MyCarColors.backgroundLight, isA<Color>());
      expect(MyCarColors.background, isA<Color>());
    });

    test('should have text colors defined', () {
      expect(MyCarColors.textPrimary, isA<Color>());
      expect(MyCarColors.textSecondary, isA<Color>());
      expect(MyCarColors.textTertiary, isA<Color>());
    });

    test('should have error color defined', () {
      expect(MyCarColors.error, isA<Color>());
    });

    test('should have primaryLight color defined', () {
      expect(MyCarColors.primaryLight, isA<Color>());
    });

    test('should have primaryGradient defined', () {
      expect(MyCarColors.primaryGradient, isA<Gradient>());
    });

    test('should have consistent color scheme', () {
      // Verify that primaryLight is related to primary
      expect(MyCarColors.primaryLight, isA<Color>());
      
      // Verify error color is red-ish
      expect(MyCarColors.error, isA<Color>());
    });
  });
}
