import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _androidAttribute(String source, String element, String attribute) {
  final elementTag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return RegExp(
    'android:$attribute="([^"]+)"',
  ).firstMatch(elementTag)!.group(1)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV launcher icons meet density-specific minimum sizes', () async {
    const expectedSizes = {
      'mdpi': 80,
      'hdpi': 120,
      'xhdpi': 160,
      'xxhdpi': 240,
      'xxxhdpi': 320,
    };

    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/'
        'mipmap-television-$density/ic_launcher.webp',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(
        (frame.image.width, frame.image.height),
        (size, size),
        reason: file.path,
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('TV adaptive launcher icon stays centered in the safe zone', () async {
    final adaptiveIcon = File(
      'android/app/src/main/res/'
      'mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(adaptiveIcon, 'foreground', 'drawable'),
      '@drawable/ic_launcher_foreground_tv',
    );
    expect(
      _androidAttribute(adaptiveIcon, 'background', 'drawable'),
      '@color/ic_launcher_background',
    );

    // The TV foreground wraps the shared brand art: its visible content must
    // sit inside the 66% safe zone of the 432-wide art canvas and stay
    // centered.
    final art = File(
      'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground_art.png',
    );
    final codec = await ui.instantiateImageCodec(await art.readAsBytes());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    addTearDown(image.dispose);
    addTearDown(codec.dispose);
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    const canvas = 432;
    var left = canvas, top = canvas, right = 0, bottom = 0;
    final bytes = data!.buffer.asUint8List();
    for (var y = 0; y < canvas; y++) {
      for (var x = 0; x < canvas; x++) {
        if (bytes[(y * canvas + x) * 4 + 3] > 8) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    const safeZone = 72.0;
    expect(left, greaterThanOrEqualTo(safeZone));
    expect(top, greaterThanOrEqualTo(safeZone));
    expect(right + 1, lessThanOrEqualTo(canvas - safeZone));
    expect(bottom + 1, lessThanOrEqualTo(canvas - safeZone));
    expect((left + right) / 2, closeTo(canvas / 2, 1));
    expect((top + bottom) / 2, closeTo(canvas / 2, 1));
  });
}
