import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/services/profile_photo_storage.dart';

void main() {
  late Directory docs;
  late Directory picker;
  var clock = DateTime(2026, 11, 10, 9);

  ProfilePhotoStorage newStorage() =>
      ProfilePhotoStorage(documentsDir: () async => docs, now: () => clock);

  File pickedPhoto(String name, String content) =>
      File('${picker.path}/$name')..writeAsStringSync(content);

  setUp(() {
    docs = Directory.systemTemp.createTempSync('docs_');
    picker = Directory.systemTemp.createTempSync('picker_');
    clock = DateTime(2026, 11, 10, 9);
  });

  tearDown(() {
    docs.deleteSync(recursive: true);
    picker.deleteSync(recursive: true);
  });

  test('copia la foto a la app y conserva la extensión', () async {
    final source = pickedPhoto('IMG_1.png', 'foto-1');

    final saved = await newStorage().save(source.path);

    expect(File(saved).parent.path, docs.path);
    expect(saved, endsWith('.png'));
    expect(File(saved).readAsStringSync(), 'foto-1');
    // La copia es independiente del archivo temporal del selector.
    source.deleteSync();
    expect(File(saved).existsSync(), isTrue);
  });

  test('sin extensión usa .jpg', () async {
    final saved = await newStorage().save(pickedPhoto('IMG', 'x').path);

    expect(saved, endsWith('.jpg'));
  });

  test('al reemplazar borra la foto anterior de la app', () async {
    final storage = newStorage();
    final first = await storage.save(pickedPhoto('a.jpg', 'uno').path);
    clock = clock.add(const Duration(seconds: 1));

    final second = await storage.save(
      pickedPhoto('b.jpg', 'dos').path,
      replacing: first,
    );

    expect(second, isNot(first));
    expect(File(first).existsSync(), isFalse);
    expect(File(second).readAsStringSync(), 'dos');
  });

  test('no borra archivos que no guardó la app', () async {
    final foreign = File('${picker.path}/otra.jpg')..writeAsStringSync('otra');

    await newStorage().save(
      pickedPhoto('b.jpg', 'dos').path,
      replacing: foreign.path,
    );

    expect(foreign.existsSync(), isTrue);
  });

  test('reemplazar una foto que ya no existe no falla', () async {
    final saved = await newStorage().save(
      pickedPhoto('b.jpg', 'dos').path,
      replacing: '${docs.path}/profile_photo_1.jpg',
    );

    expect(File(saved).existsSync(), isTrue);
  });
}
