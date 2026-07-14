import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';

class SingleInstanceLock {
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;
  ServerSocket? _activationServer;

  static const _activationCommand = 'show';
  static const _activationRetryCount = 10;

  SingleInstanceLock._internal();

  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  Future<bool> acquire() async {
    final lockFilePath = await appPath.lockFilePath;
    final lockFile = File(lockFilePath);
    try {
      await lockFile.create();
      _accessFile = await lockFile.open(mode: FileMode.write);
      await _accessFile?.lock();
      return true;
    } catch (_) {
      await _activateExistingInstance(lockFilePath);
      return false;
    }
  }

  Future<void> startActivationServer(Future<void> Function() onActivate) async {
    if (!system.isWindows || _activationServer != null) {
      return;
    }
    final lockFilePath = await appPath.lockFilePath;
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _activationServer = server;
      await File(
        _portFilePath(lockFilePath),
      ).writeAsString(server.port.toString(), flush: true);
      server.listen((socket) async {
        try {
          final command = await utf8.decoder.bind(socket).join();
          if (command == _activationCommand) {
            await onActivate();
          }
        } finally {
          socket.destroy();
        }
      });
    } catch (_) {}
  }

  String _portFilePath(String lockFilePath) => '$lockFilePath.port';

  Future<void> _activateExistingInstance(String lockFilePath) async {
    if (!system.isWindows) {
      return;
    }
    final portFile = File(_portFilePath(lockFilePath));
    for (var attempt = 0; attempt < _activationRetryCount; attempt++) {
      try {
        final port = int.tryParse(await portFile.readAsString());
        if (port != null) {
          final socket = await Socket.connect(
            InternetAddress.loopbackIPv4,
            port,
            timeout: const Duration(milliseconds: 250),
          );
          socket.write(_activationCommand);
          await socket.flush();
          await socket.close();
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}

final singleInstanceLock = SingleInstanceLock();
