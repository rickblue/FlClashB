import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import '../helpers/test_app.dart';

final _viewSizeOverride = viewSizeProvider.overrideWithBuild(
  (_, _) => const Size(1200, 1000),
);

void main() {
  test('yaml folding follows indentation', () {
    final chunks = const YamlCodeChunkAnalyzer().run(
      CodeLines.fromText('''
proxies:
  - name: first
    type: ss
  - name: second
    type: trojan
rules:
  - MATCH,DIRECT
'''),
    );

    expect(chunks, const [
      CodeChunk(0, 5),
      CodeChunk(1, 3),
      CodeChunk(3, 5),
      CodeChunk(5, 8),
    ]);
  });

  test('yaml folding preserves collapsed chunks after edits', () {
    final chunks = const YamlCodeChunkAnalyzer().run(
      CodeLines.of([
        const CodeLine('proxies:', [
          CodeLine('  - name: first'),
          CodeLine('    type: ss'),
        ]),
        const CodeLine('rules:'),
        const CodeLine('  - MATCH,DIRECT'),
      ]),
    );

    expect(chunks, const [CodeChunk(0, 1), CodeChunk(1, 3)]);
  });

  testWidgets('page down scrolls the editor', (tester) async {
    final content = List<String>.generate(
      200,
      (index) => 'line: $index',
    ).join('\n');
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: EditorPage(title: 'Editor', content: content),
      ),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(CodeEditor));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    expect(scrollable.position.pixels, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();

    expect(scrollable.position.pixels, 0);
  });

  testWidgets('import from URL shows a translated network error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [_viewSizeOverride],
        child: const EditorPage(
          title: 'Editor',
          content: '',
          onSave: _noopSave,
          supportRemoteDownload: true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('External fetch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from URL'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'http://127.0.0.1/anything',
    );
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // flutter_test's mocked HttpClient answers with HTTP 400, which maps to
    // the localized network exception message in the snackbar.
    expect(
      find.text('Network error, please check your connection and try again'),
      findsOneWidget,
    );
  });
}

void _noopSave(BuildContext context, String title, String content) {}
