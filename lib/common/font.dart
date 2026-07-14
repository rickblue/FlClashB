import 'dart:io';

import 'package:flutter/services.dart';
import 'package:system_fonts/system_fonts.dart';

class SystemFontLoader {
  final Set<String> _loadedFamilies = <String>{};

  List<String> get families {
    try {
      final families = SystemFonts().getFontList().toSet().toList()..sort();
      return families;
    } catch (_) {
      return const <String>[];
    }
  }

  Future<bool> load(String? family) async {
    if (family == null || family.isEmpty || _loadedFamilies.contains(family)) {
      return true;
    }
    final path = SystemFonts().getFontMap()[family];
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
}

final systemFontLoader = SystemFontLoader();
