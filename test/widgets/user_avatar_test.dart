import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/user_provider.dart';
import 'package:new_my_car_app/screens/home_screen.dart';
import 'package:new_my_car_app/widgets/user_avatar.dart';

import '../helpers/supabase_test_init.dart';

class _PhotoUserProvider extends UserProvider {
  String? photo;

  @override
  String? get userPhotoPath => photo;
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Image _image(WidgetTester tester) => tester.widget<Image>(
  find.descendant(of: find.byType(UserAvatar), matching: find.byType(Image)),
);

void main() {
  group('UserAvatar', () {
    testWidgets('sin foto muestra la imagen por defecto', (tester) async {
      await tester.pumpWidget(_app(const UserAvatar(photoPath: null)));

      final provider = _image(tester).image;
      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName, UserAvatar.defaultAsset);
    });

    testWidgets('con ruta vacía muestra la imagen por defecto', (tester) async {
      await tester.pumpWidget(_app(const UserAvatar(photoPath: '')));

      expect(_image(tester).image, isA<AssetImage>());
    });

    testWidgets('con foto usa el archivo del usuario', (tester) async {
      await tester.pumpWidget(
        _app(const UserAvatar(photoPath: '/docs/profile_photo_1.jpg')),
      );

      final provider = _image(tester).image;
      expect(provider, isA<FileImage>());
      expect((provider as FileImage).file.path, '/docs/profile_photo_1.jpg');
    });
  });

  group('HomeScreen', () {
    Future<void> pumpHome(
      WidgetTester tester,
      _PhotoUserProvider userProvider,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CarProvider()),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el inicio muestra la foto de perfil y la actualiza', (
      tester,
    ) async {
      final userProvider = _PhotoUserProvider();
      await pumpHome(tester, userProvider);
      expect(_image(tester).image, isA<AssetImage>());

      // El usuario cambia la foto desde Ajustes → Perfil.
      userProvider.photo = '/docs/profile_photo_2.jpg';
      userProvider.notifyListeners();
      await tester.pump();

      final provider = _image(tester).image;
      expect(provider, isA<FileImage>());
      expect((provider as FileImage).file.path, '/docs/profile_photo_2.jpg');
    });
  });

  group('UserProvider', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await initSupabaseForTests();
    });

    test('cambiar el correo conserva la foto de perfil', () async {
      final provider = UserProvider();
      await provider.loadUser();
      await provider.updatePhoto('/docs/profile_photo_3.jpg');

      await provider.updateEmail('nuevo@correo.com');

      expect(provider.userPhotoPath, '/docs/profile_photo_3.jpg');
      expect(provider.userEmail, 'nuevo@correo.com');
    });
  });
}
