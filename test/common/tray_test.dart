import 'package:fl_clash/common/tray.dart';
import 'package:test/test.dart';

void main() {
  group('AppTray.getTrayIcon', () {
    final windows = AppTray.forPlatform(isMacOS: false, isWindows: true);
    final macOS = AppTray.forPlatform(isMacOS: true, isWindows: false);
    final linux = AppTray.forPlatform(isMacOS: false, isWindows: false);

    test('windows loads the robotech icon as ICO', () {
      expect(windows.getTrayIcon(), 'res/robotech.ico');
    });

    test('linux loads the colored robotech image', () {
      expect(linux.getTrayIcon(), 'res/robotech.jpg');
    });

    test('macOS loads the colored robotech image', () {
      expect(macOS.getTrayIcon(), 'res/robotech.jpg');
    });
  });
}
