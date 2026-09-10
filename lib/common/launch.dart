import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'system.dart';

const _linuxAutostartDelaySeconds = 5;

@visibleForTesting
String addLinuxAutostartDelay(String contents) {
  const key = 'X-GNOME-Autostart-Delay=';
  final lines = contents.trimRight().split('\n')
    ..removeWhere((line) => line.startsWith(key));
  return '${lines.join('\n')}\n$key$_linuxAutostartDelaySeconds\n';
}

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launcher.setup(appName: appName, appPath: Platform.resolvedExecutable);
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  @visibleForTesting
  static LaunchAtStartup launcher = launchAtStartup;

  Future<bool> get isEnable async {
    return launcher.isEnabled();
  }

  Future<bool> enable() async {
    final enabled = await launcher.enable();
    if (enabled) {
      await _ensureLinuxAutostartDelay();
    }
    return enabled;
  }

  Future<bool> disable() async {
    return launcher.disable();
  }

  Future<void> updateStatus(bool isAutoLaunch) async {
    if (kDebugMode) {
      return;
    }
    if (await isEnable == isAutoLaunch) {
      if (isAutoLaunch) {
        await _ensureLinuxAutostartDelay();
      }
      return;
    }
    if (isAutoLaunch == true) {
      await enable();
    } else {
      await disable();
    }
  }

  Future<void> _ensureLinuxAutostartDelay() async {
    if (!system.isLinux) return;
    final desktopFile = File(
      '${Platform.environment['HOME']}/.config/autostart/$appName.desktop',
    );
    if (!await desktopFile.exists()) return;
    final contents = await desktopFile.readAsString();
    final updated = addLinuxAutostartDelay(contents);
    if (updated != contents) {
      await desktopFile.writeAsString(updated);
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;
