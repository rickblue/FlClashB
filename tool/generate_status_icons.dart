import 'dart:io';

import 'package:image/image.dart' as image;

import 'src/icons/ico.dart';

const spriteSource = 'assets_source/images/icon/vico.png';
const appIconOutput = 'assets/images/icon.png';
const windowsAppIconOutput = 'windows/runner/resources/app_icon.ico';
const macOSAppIconDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const pngOutputDir = 'assets/images/tray/unix';
const icoOutputDir = 'assets/images/tray/windows';
const statusIconNames = ['status_1', 'status_2', 'status_3'];
const trayBaseSize = 18;
const trayScales = [1, 2, 3, 4];
const macOSAppIconSizes = [16, 32, 64, 128, 256, 512, 1024];

Future<void> main() async {
  final source = File(spriteSource);
  if (!source.existsSync()) {
    stderr.writeln('Missing icon sprite: ${source.path}');
    exitCode = 1;
    return;
  }
  final sprite = image.decodePng(await source.readAsBytes());
  if (sprite == null) {
    stderr.writeln('Unable to decode icon sprite: ${source.path}');
    exitCode = 1;
    return;
  }
  final logo = _extractLargestLogo(sprite);
  await _writePng(File(appIconOutput), _render(logo, 1024));
  for (final size in macOSAppIconSizes) {
    await _writePng(
      File('$macOSAppIconDir/app_icon_$size.png'),
      _render(logo, size),
    );
  }
  await _writeIco(logo, File(windowsAppIconOutput), sizes: icoSizes);
  for (var status = 0; status < statusIconNames.length; status++) {
    final name = statusIconNames[status];
    final statusLogo = _buildTrayLogo(status);
    await _writeTrayVariants(statusLogo, name);
    await _writeIco(
      statusLogo,
      File('$icoOutputDir/$name.ico'),
      sizes: trayIcoSizes,
    );
  }
}

image.Image _extractLargestLogo(image.Image sprite) {
  final bounds = <_Bounds>[];
  var start = -1;
  for (var x = 0; x <= sprite.width; x++) {
    final occupied = x < sprite.width && _columnHasContent(sprite, x);
    if (occupied && start == -1) {
      start = x;
    } else if (!occupied && start != -1) {
      bounds.add(_contentBounds(sprite, start, x - 1));
      start = -1;
    }
  }
  bounds.removeWhere((value) => value.width < 16 || value.height < 16);
  if (bounds.isEmpty) {
    throw StateError('No non-transparent icon found in $spriteSource');
  }
  bounds.sort((a, b) => b.area.compareTo(a.area));
  final largest = bounds.first;
  final crop = image.copyCrop(
    sprite,
    x: largest.left,
    y: largest.top,
    width: largest.width,
    height: largest.height,
  );
  final contentSide = crop.width > crop.height ? crop.width : crop.height;
  final padding = (contentSide * 0.06).round();
  final side = contentSide + padding * 2;
  final canvas = image.Image(width: side, height: side, numChannels: 4)
    ..clear(image.ColorRgba8(0, 0, 0, 0));
  image.compositeImage(canvas, crop, center: true);
  return canvas;
}

bool _columnHasContent(image.Image source, int x) {
  for (var y = 0; y < source.height; y++) {
    if (source.getPixel(x, y).aNormalized > 0.02) {
      return true;
    }
  }
  return false;
}

_Bounds _contentBounds(image.Image source, int left, int right) {
  var top = source.height;
  var bottom = 0;
  for (var x = left; x <= right; x++) {
    for (var y = 0; y < source.height; y++) {
      if (source.getPixel(x, y).aNormalized <= 0.02) {
        continue;
      }
      if (y < top) {
        top = y;
      }
      if (y > bottom) {
        bottom = y;
      }
    }
  }
  return _Bounds(left: left, top: top, right: right, bottom: bottom);
}

image.Image _buildTrayLogo(int status) {
  final stateColor = switch (status) {
    0 => image.ColorRgba8(142, 142, 147, 255),
    1 => image.ColorRgba8(255, 0, 23, 255),
    2 => image.ColorRgba8(0, 200, 103, 255),
    _ => throw ArgumentError.value(status, 'status'),
  };
  final canvas = image.Image(width: 256, height: 256, numChannels: 4)
    ..clear(image.ColorRgba8(0, 0, 0, 0));
  final black = image.ColorRgba8(8, 8, 10, 255);
  final white = image.ColorRgba8(255, 255, 255, 255);
  final transparent = image.ColorRgba8(0, 0, 0, 0);
  image.fillCircle(canvas, x: 128, y: 128, radius: 121, color: black);
  image.fillCircle(canvas, x: 128, y: 128, radius: 113, color: stateColor);
  image.fillCircle(
    canvas,
    x: 128,
    y: 128,
    radius: 94,
    color: transparent,
    blend: image.BlendMode.direct,
  );
  image.drawLine(
    canvas,
    x1: 57,
    y1: 65,
    x2: 128,
    y2: 191,
    color: black,
    thickness: 57,
  );
  image.drawLine(
    canvas,
    x1: 128,
    y1: 191,
    x2: 199,
    y2: 65,
    color: black,
    thickness: 57,
  );
  image.drawLine(
    canvas,
    x1: 57,
    y1: 65,
    x2: 128,
    y2: 191,
    color: white,
    thickness: 29,
  );
  image.drawLine(
    canvas,
    x1: 128,
    y1: 191,
    x2: 199,
    y2: 65,
    color: white,
    thickness: 29,
  );
  return canvas;
}

image.Image _render(image.Image source, int size) {
  return image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.cubic,
  );
}

Future<void> _writeTrayVariants(image.Image source, String name) async {
  for (final scale in trayScales) {
    final directory = scale == 1 ? pngOutputDir : '$pngOutputDir/$scale.0x';
    await _writePng(
      File('$directory/$name.png'),
      _render(source, trayBaseSize * scale),
    );
  }
}

Future<void> _writeIco(
  image.Image source,
  File output, {
  required List<int> sizes,
}) async {
  final entries = [
    for (final size in sizes)
      IcoEntry(size: size, png: image.encodePng(_render(source, size))),
  ];
  await output.parent.create(recursive: true);
  await output.writeAsBytes(buildIco(entries));
  stdout.writeln('Generated ${output.path}');
}

Future<void> _writePng(File output, image.Image value) async {
  await output.parent.create(recursive: true);
  await output.writeAsBytes(image.encodePng(value));
  stdout.writeln('Generated ${output.path}');
}

final class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;

  int get height => bottom - top + 1;

  int get area => width * height;
}
