import 'package:fl_clash/bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bootstrap.loadCustomThemeFont', () {
    test('skips when no custom font is set', () async {
      await expectLater(bootstrap.loadCustomThemeFont(null), completes);
    });

    test('skips the bundled JetBrainsMono', () async {
      await expectLater(
        bootstrap.loadCustomThemeFont('JetBrainsMono'),
        completes,
      );
    });

    test('loads or swallows failures for a custom family', () async {
      await expectLater(
        bootstrap.loadCustomThemeFont('NoSuchFontFamilyForTest'),
        completes,
      );
    });
  });
}
