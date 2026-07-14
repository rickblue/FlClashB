import 'package:fl_clash/common/launch.dart';
import 'package:test/test.dart';

void main() {
  group('addLinuxAutostartDelay', () {
    test('adds the GNOME startup delay', () {
      const input = '[Desktop Entry]\nType=Application\n';

      expect(
        addLinuxAutostartDelay(input),
        '[Desktop Entry]\nType=Application\nX-GNOME-Autostart-Delay=5\n',
      );
    });

    test('replaces an existing delay without duplicating it', () {
      const input =
          '[Desktop Entry]\nX-GNOME-Autostart-Delay=2\nType=Application\n';

      expect(
        addLinuxAutostartDelay(input),
        '[Desktop Entry]\nType=Application\nX-GNOME-Autostart-Delay=5\n',
      );
    });
  });
}
