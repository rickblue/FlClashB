import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:system_fonts/system_fonts.dart';

Map<String, String> parseLinuxFontConfigOutput(String output) {
  final fonts = <String, String>{};
  for (final line in const LineSplitter().convert(output)) {
    final separator = line.indexOf('\t');
    if (separator <= 0 || separator == line.length - 1) {
      continue;
    }
    final path = line.substring(separator + 1).trim();
    if (!_isSupportedFontPath(path)) {
      continue;
    }
    for (final value in line.substring(0, separator).split(',')) {
      final family = value.trim();
      if (family.isNotEmpty) {
        fonts.putIfAbsent(family, () => path);
      }
    }
  }
  return fonts;
}

bool _isSupportedFontPath(String path) {
  final extension = p.extension(path).toLowerCase();
  return extension == '.ttf' || extension == '.otf' || extension == '.ttc';
}

class SystemFontLoader {
  final Set<String> _loadedFamilies = <String>{};
  Map<String, String>? _fontMap;

  List<String> get families {
    try {
      final families = _getFontMap().keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return families;
    } catch (_) {
      return const <String>[];
    }
  }

  List<String> refreshFamilies() {
    _fontMap = null;
    SystemFonts().rescan();
    return families;
  }

  Future<bool> load(String? family) async {
    if (family == null || family.isEmpty || _loadedFamilies.contains(family)) {
      return true;
    }
    final path = _getFontMap()[family];
    if (path == null) {
      return false;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFamilies.add(family);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _getFontMap() {
    return _fontMap ??= Platform.isLinux
        ? _getLinuxFontMap()
        : Map<String, String>.from(SystemFonts().getFontMap());
  }

  Map<String, String> _getLinuxFontMap() {
    try {
      final result = Process.runSync('fc-list', [
        '--format=%{family}\t%{file}\n',
      ]);
      if (result.exitCode == 0) {
        final fonts = parseLinuxFontConfigOutput(result.stdout.toString());
        fonts.removeWhere((_, path) => !File(path).existsSync());
        if (fonts.isNotEmpty) {
          return fonts;
        }
      }
    } catch (_) {}
    return _scanLinuxFontDirectories();
  }

  Map<String, String> _scanLinuxFontDirectories() {
    final home = Platform.environment['HOME'];
    final directories = <String>[
      '/usr/share/fonts',
      '/usr/local/share/fonts',
      if (home != null) '$home/.fonts',
      if (home != null) '$home/.local/share/fonts',
    ];
    final fonts = <String, String>{};
    for (final directoryPath in directories) {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        continue;
      }
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && _isSupportedFontPath(entity.path)) {
          fonts.putIfAbsent(
            p.basenameWithoutExtension(entity.path),
            () => entity.path,
          );
        }
      }
    }
    return fonts;
  }
}

final systemFontLoader = SystemFontLoader();
