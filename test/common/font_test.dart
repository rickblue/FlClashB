import 'package:fl_clash/common/font.dart';
import 'package:test/test.dart';

void main() {
  group('parseLinuxFontConfigOutput', () {
    test('extracts each family name and supports TTC collections', () {
      const output =
          'Noto Sans CJK SC,Noto Sans CJK SC Medium\t'
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc\n'
          'DejaVu Sans\t/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf\n';

      expect(parseLinuxFontConfigOutput(output), {
        'Noto Sans CJK SC':
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc',
        'Noto Sans CJK SC Medium':
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc',
        'DejaVu Sans': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      });
    });

    test('ignores malformed records and unsupported font files', () {
      const output =
          'Malformed record\n'
          'Bitmap Font\t/usr/share/fonts/example.pcf\n'
          '\t/usr/share/fonts/example.ttf\n';

      expect(parseLinuxFontConfigOutput(output), isEmpty);
    });
  });
}
