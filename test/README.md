# Tests para MyCar App

Este directorio contiene los tests unitarios y de widgets para la aplicación MyCar.

## Estructura de Tests

```
test/
├── models/
│   ├── car_test.dart          # Tests para el modelo Car
│   └── income_test.dart       # Tests para el modelo Income
├── widgets/
│   └── home_screen_test.dart  # Tests para HomeScreen widget
├── utils/
│   └── color_utils_test.dart  # Tests para utilidades de colores
└── widget_test.dart           # Test principal de la app
```

## Ejecutar Tests

### Ejecutar todos los tests
```bash
flutter test
```

### Ejecutar un archivo específico
```bash
flutter test test/models/car_test.dart
```

### Ejecutar con cobertura
```bash
flutter test --coverage
```

### Ver cobertura en HTML
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Tipos de Tests

### Tests de Modelos (`models/`)
- **car_test.dart**: Prueba la creación, serialización y deserialización del modelo Car
- **income_test.dart**: Prueba la creación, serialización y deserialización del modelo Income

### Tests de Widgets (`widgets/`)
- **home_screen_test.dart**: Prueba la renderización y comportamiento del HomeScreen

### Tests de Utilidades (`utils/`)
- **color_utils_test.dart**: Verifica que los colores estén correctamente definidos

## Cobertura de Tests

Los tests actuales cubren:
- ✅ Modelos de datos (Car, Income)
- ✅ Conversión a/desde Map
- ✅ Widgets principales
- ✅ Utilidades de colores

## Agregar Nuevos Tests

Para agregar nuevos tests:

1. Crea un archivo `*_test.dart` en el directorio apropiado
2. Importa `package:flutter_test/flutter_test.dart`
3. Usa `group()` para organizar tests relacionados
4. Usa `test()` o `testWidgets()` según el tipo de test
5. Ejecuta `flutter test` para verificar

### Ejemplo de Test Unitario
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car.dart';

void main() {
  group('Car Model Tests', () {
    test('should create a Car', () {
      final car = Car(
        userId: 'test-user-uuid',
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
      );
      expect(car.brand, 'Toyota');
      expect(car.userId, 'test-user-uuid');
    });
  });
}
```

### Ejemplo de Test de Widget
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/screens/home_screen.dart';

void main() {
  testWidgets('should display title', (WidgetTester tester) async {
    await tester.pumpWidget(const HomeScreen());
    expect(find.text('Home'), findsOneWidget);
  });
}
```
