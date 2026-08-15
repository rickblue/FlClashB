import 'dart:io';

import 'package:fl_clash/common/window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final calls = <MethodCall>[];
  var isAlwaysOnTop = false;

  setUp(() {
    calls.clear();
    isAlwaysOnTop = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'isMinimized') {
            return false;
          }
          if (call.method == 'isAlwaysOnTop') {
            return isAlwaysOnTop;
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'show restores taskbar visibility before presenting the window',
    () async {
      await Window().show();

      expect(calls.map((call) => call.method), [
        'setSkipTaskbar',
        'isMinimized',
        'show',
        if (Platform.isLinux) ...['isAlwaysOnTop', 'setAlwaysOnTop', 'restore'],
        'focus',
        if (Platform.isLinux) 'setAlwaysOnTop',
      ]);
      expect(calls.first.arguments, {'isSkipTaskbar': false});
      if (Platform.isLinux) {
        expect(calls[4].arguments, {'isAlwaysOnTop': true});
        expect(calls.last.arguments, {'isAlwaysOnTop': false});
      }
    },
  );

  test('show coalesces concurrent requests', () async {
    await Future.wait([Window().show(), Window().show(), Window().show()]);

    expect(calls.where((call) => call.method == 'show'), hasLength(1));
  });

  test('show preserves an existing always-on-top setting', () async {
    isAlwaysOnTop = true;

    await Window().show();

    if (Platform.isLinux) {
      expect(calls.where((call) => call.method == 'setAlwaysOnTop'), isEmpty);
    }
  });

  test('minimize hides on Linux so the tray can restore it', () async {
    await Window().minimize();

    if (Platform.isLinux) {
      // GNOME Wayland cannot restore a compositor-minimized window, so on
      // Linux the window is hidden (unmapped) instead of iconified; the tray
      // "show" action maps it again via show().
      expect(calls.map((call) => call.method), ['hide', 'setSkipTaskbar']);
      expect(calls[1].arguments, {'isSkipTaskbar': true});
    } else {
      expect(calls.map((call) => call.method), ['minimize']);
    }
  });
}
