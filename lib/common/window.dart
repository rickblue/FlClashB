import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  static Window? _instance;
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void>? _showOperation;

  Window._internal();

  factory Window() {
    _instance ??= Window._internal();
    return _instance!;
  }

  Future<void> init(
    int version,
    WindowProps props, {
    bool silentLaunch = false,
  }) async {
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    if (system.isWindows) {
      protocol.register('clash');
      protocol.register('clashmeta');
      protocol.register('flclash');
    }
    await windowManager.ensureInitialized();
    await singleInstanceLock.startActivationServer(() async {
      await _readyCompleter.future;
      await show();
    });
    final WindowOptions windowOptions = WindowOptions(
      size: props.size,
      minimumSize: const Size(380, 400),
    );
    if (!system.isMacOS || version > 10) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    await windowManager.setMaximizable(true);
    await _windowPosition(props);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      commonPrint.log('window readyToShow silentLaunch:$silentLaunch');
      await windowManager.setPreventClose(true);
      if (!silentLaunch) {
        await show();
      }
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    });
  }

  Future<void> _windowPosition(WindowProps props) async {
    if (!system.isMacOS) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      final right = left + props.width;
      final bottom = top + props.height;
      if (left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        final displays = await screenRetriever.getAllDisplays();
        final isPositionValid = displays.any((display) {
          final displayBounds = Rect.fromLTWH(
            display.visiblePosition!.dx,
            display.visiblePosition!.dy,
            display.size.width,
            display.size.height,
          );
          return displayBounds.contains(Offset(left, top)) ||
              displayBounds.contains(Offset(right, bottom));
        });
        if (isPositionValid) {
          await windowManager.setPosition(Offset(left, top));
        }
      }
    }
  }

  Future<void> show() {
    final pendingOperation = _showOperation;
    if (pendingOperation != null) {
      return pendingOperation;
    }
    final operation = _show();
    _showOperation = operation;
    return operation.whenComplete(() {
      if (identical(_showOperation, operation)) {
        _showOperation = null;
      }
    });
  }

  Future<void> _show() async {
    commonPrint.log('window show');
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    if (system.isLinux) {
      final wasAlwaysOnTop = await windowManager.isAlwaysOnTop();
      if (!wasAlwaysOnTop) {
        await windowManager.setAlwaysOnTop(true);
      }
      try {
        // GNOME can reject a repeated gtk_window_present() after a tray menu
        // callback. A short keep-above pulse still maps the window reliably.
        await windowManager.restore();
        await windowManager.focus();
        render?.resume();
        if (!wasAlwaysOnTop) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      } finally {
        if (!wasAlwaysOnTop) {
          await windowManager.setAlwaysOnTop(false);
        }
        render?.resume();
      }
      return;
    }
    await windowManager.focus();
    render?.resume();
  }

  Future<bool> get isVisible async {
    final value = await windowManager.isVisible();
    commonPrint.log('window visible check: $value');
    return value;
  }

  Future<void> close() async {
    await windowManager.close();
  }

  void forceExit() {
    exit(0);
  }

  Future<void> hide() async {
    render?.pause();
    commonPrint.log('window hide');
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  /// Minimizes the window.
  ///
  /// On Linux this hides (unmaps) the window instead of asking the window
  /// manager to iconify it: GNOME Wayland cannot restore a
  /// compositor-minimized window from the client side (GTK deiconify is
  /// X11-only and GDK never reports the ICONIFIED state on Wayland), so a
  /// tray "show" action would never bring the window back. Hide/show
  /// (unmap/map) is fully supported on Wayland, so the tray can always
  /// restore the window via [show].
  Future<void> minimize() async {
    if (system.isLinux) {
      await hide();
    } else {
      await windowManager.minimize();
    }
  }

  Future<Size?> get size async {
    if (!kIsWeb && system.isDesktop) {
      final value = await windowManager.getSize();
      commonPrint.log('window size: $value');
      return value;
    }
    return null;
  }
}

final window = system.isDesktop ? Window() : null;
