import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

class EditorPage extends ConsumerStatefulWidget {
  final String title;
  final String? content;
  final List<Language> languages;
  final bool supportRemoteDownload;
  final bool titleEditable;
  final Function(BuildContext context, String title, String content)? onSave;
  final Future<bool> Function(
    BuildContext context,
    String title,
    String content,
  )?
  onPop;

  const EditorPage({
    super.key,
    required this.title,
    required this.content,
    this.titleEditable = false,
    this.onSave,
    this.onPop,
    this.supportRemoteDownload = false,
    this.languages = const [Language.yaml],
  });

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late CodeLineEditingController _controller;
  late CodeFindController _findController;
  late TextEditingController _titleController;
  late FocusNode _focusNode;
  late CodeScrollController _scrollController;
  late _CurrentLineHighlightStyle _currentLineHighlightStyle;
  late bool readOnly = false;
  late final SelectionToolbarController _toolbarController;

  @override
  void initState() {
    super.initState();
    readOnly = widget.onSave == null;
    _toolbarController = ContextMenuControllerImpl(readOnly);
    _focusNode = FocusNode();
    _scrollController = CodeScrollController();
    _currentLineHighlightStyle = const _CurrentLineHighlightStyle(
      foreground: Color(0xFF000000),
      background: Colors.transparent,
    );
    _controller = CodeLineEditingController(
      codeLines: CodeLines.fromText(widget.content ?? ''),
      spanBuilder: _buildCurrentLineTextSpan,
    );
    _findController = CodeFindController(_controller);
    _titleController = TextEditingController(text: widget.title);
    _focusNode.onKeyEvent = (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.pageUp) {
        _scrollPage(forward: false);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.pageDown) {
        _scrollPage(forward: true);
        return KeyEventResult.handled;
      }
      if (system.isDesktop) {
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _controller.moveCursor(AxisDirection.up);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _controller.moveCursor(AxisDirection.down);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _controller.selection.endIndex;
        _controller.moveCursor(AxisDirection.left);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _controller.moveCursor(AxisDirection.right);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = widget.content;
      if (content != null && oldWidget.content != content) {
        _controller.text = content;
        _controller.clearHistory();
      }
    });
  }

  @override
  void dispose() {
    _toolbarController.hide(context);
    _findController.dispose();
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _scrollController
      ..verticalScroller.dispose()
      ..horizontalScroller.dispose()
      ..dispose();
    super.dispose();
  }

  TextSpan _buildCurrentLineTextSpan({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    if (index != _controller.selection.extentIndex) {
      return textSpan;
    }
    return _withCurrentLineHighlight(textSpan, style);
  }

  TextSpan _withCurrentLineHighlight(TextSpan textSpan, TextStyle style) {
    final highlight = _currentLineHighlightStyle;
    return TextSpan(
      text: textSpan.text,
      style: (textSpan.style ?? style).copyWith(
        color: highlight.foreground,
        backgroundColor: highlight.background,
      ),
      children: textSpan.children
          ?.map<InlineSpan>(
            (child) => child is TextSpan
                ? _withCurrentLineHighlight(child, style)
                : child,
          )
          .toList(growable: false),
    );
  }

  void _scrollPage({required bool forward}) {
    final controller = _scrollController.verticalScroller;
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    final target =
        (position.pixels +
                (forward
                    ? position.viewportDimension
                    : -position.viewportDimension))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if (target != position.pixels) {
      controller.jumpTo(target);
    }
  }

  void _updateCurrentLineHighlightStyle(_CurrentLineHighlightStyle value) {
    if (_currentLineHighlightStyle == value) {
      return;
    }
    _currentLineHighlightStyle = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forceRepaint();
      }
    });
  }

  void _handleSearch() {
    _findController.findMode();
  }

  Future<void> _handleImportFormFile() async {
    final file = await picker.pickerFile();
    if (file == null) {
      return;
    }
    final res = utf8.decode(await file.readBytes());
    if (!mounted) {
      return;
    }
    _controller.text = res;
  }

  Future<void> _handleImportFormUrl() async {
    final appLocalizations = context.appLocalizations;
    final url = await dialogs.showCommonDialog(
      child: InputDialog(
        title: appLocalizations.import,
        value: '',
        labelText: appLocalizations.url,
        inputFormatters: TextInputLimits.limit(TextInputLimits.url),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
    if (url == null) {
      return;
    }
    try {
      final res = await request.getTextResponseForUrl(url);
      if (!mounted) {
        return;
      }
      _controller.text = res.data ?? '';
    } catch (e) {
      if (!mounted) {
        return;
      }
      final appLocalizations = context.appLocalizations;
      context.showSnackBar(
        networkErrorMessage(e, appLocalizations) ??
            appLocalizations.unknownNetworkError,
      );
    }
  }

  Future<bool> _handlePop(BuildContext context) async {
    final onPop = widget.onPop;
    if (onPop == null) {
      return true;
    }
    final res = await onPop(context, _titleController.text, _controller.text);
    return res && context.mounted;
  }

  @override
  Widget build(BuildContext context) {
    final editorColors = ref.watch(
      themeSettingProvider.select(
        (state) => (
          foreground: state.editorCurrentLineForegroundColor,
          background: state.editorCurrentLineBackgroundColor,
        ),
      ),
    );
    final currentLineHighlightStyle = _CurrentLineHighlightStyle(
      foreground: editorColors.foreground == null
          ? context.colorScheme.onSurface
          : Color(editorColors.foreground!),
      background: editorColors.background == null
          ? context.colorScheme.primary.withValues(alpha: 0.18)
          : Color(editorColors.background!),
    );
    _updateCurrentLineHighlightStyle(currentLineHighlightStyle);
    return CommonPopScope(
      onPop: _handlePop,
      child: CommonScaffold(
        appBar: AppBar(
          title: _EditorTitleField(
            controller: _titleController,
            enabled: widget.titleEditable,
          ),
          actions: genActions([
            if (!readOnly)
              _EditorSaveAction(
                controller: _controller,
                titleController: _titleController,
                savedContent: widget.content,
                savedTitle: widget.title,
                onSave: widget.onSave!,
              ),
            _EditorMenuAction(
              controller: _controller,
              readOnly: readOnly,
              supportRemoteDownload: widget.supportRemoteDownload,
              onSearch: _handleSearch,
              onImportFromUrl: _handleImportFormUrl,
              onImportFromFile: _handleImportFormFile,
            ),
          ]),
        ),
        body: _EditorBody(
          controller: _controller,
          findController: _findController,
          toolbarController: _toolbarController,
          focusNode: _focusNode,
          scrollController: _scrollController,
          readOnly: readOnly,
          languages: widget.languages,
          currentLineHighlightStyle: currentLineHighlightStyle,
          isLoading: widget.content == null,
        ),
      ),
    );
  }
}

class _EditorTitleField extends StatelessWidget {
  const _EditorTitleField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLength: 20,
      enabled: enabled,
      controller: controller,
      decoration: InputDecoration(
        border: const NoInputBorder(),
        counter: const SizedBox(),
        hintText: context.appLocalizations.unnamed,
      ),
      style: context.textTheme.titleLarge,
      autofocus: false,
    );
  }
}

class _EditorSaveAction extends StatelessWidget {
  const _EditorSaveAction({
    required this.controller,
    required this.titleController,
    required this.savedContent,
    required this.savedTitle,
    required this.onSave,
  });

  final CodeLineEditingController controller;
  final TextEditingController titleController;
  final String? savedContent;
  final String savedTitle;
  final Function(BuildContext context, String title, String content) onSave;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_, _, _) => ValueListenableBuilder(
        valueListenable: titleController,
        builder: (context, _, _) {
          final isDirty =
              controller.text != savedContent ||
              titleController.text != savedTitle;
          return IconButton(
            tooltip: context.appLocalizations.save,
            onPressed: isDirty
                ? () => onSave(context, titleController.text, controller.text)
                : null,
            icon: const Icon(Icons.save),
          );
        },
      ),
    );
  }
}

class _EditorMenuAction extends ConsumerWidget {
  const _EditorMenuAction({
    required this.controller,
    required this.readOnly,
    required this.supportRemoteDownload,
    required this.onSearch,
    required this.onImportFromUrl,
    required this.onImportFromFile,
  });

  final CodeLineEditingController controller;
  final bool readOnly;
  final bool supportRemoteDownload;
  final VoidCallback onSearch;
  final VoidCallback onImportFromUrl;
  final VoidCallback onImportFromFile;

  Future<void> _selectCurrentLineColor(
    BuildContext context,
    WidgetRef ref, {
    required bool foreground,
  }) async {
    final theme = ref.read(themeSettingProvider);
    final current = foreground
        ? theme.editorCurrentLineForegroundColor
        : theme.editorCurrentLineBackgroundColor;
    final defaultColor = foreground
        ? context.colorScheme.onSurface
        : context.colorScheme.primary.withValues(alpha: 0.18);
    final result = await dialogs.showCommonDialog<_EditorColorSelection>(
      context: context,
      child: _EditorColorDialog(
        title: foreground
            ? context.appLocalizations.currentLineForeground
            : context.appLocalizations.currentLineBackground,
        initialColor: current == null ? defaultColor : Color(current),
      ),
    );
    if (result == null) {
      return;
    }
    ref.read(themeSettingProvider.notifier).update((state) {
      return foreground
          ? state.copyWith(editorCurrentLineForegroundColor: result.value)
          : state.copyWith(editorCurrentLineBackgroundColor: result.value);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_, _, _) {
        return CommonPopupBox(
          targetBuilder: (open) {
            return IconButton(
              tooltip: context.appLocalizations.more,
              onPressed: () {
                final isMobile = ref.read(isMobileViewProvider);
                open(offset: Offset(0, isMobile ? 0 : 20));
              },
              icon: const Icon(Icons.more_vert),
            );
          },
          popupBuilder: (_) => CommonPopupMenu(
            items: [
              CommonPopupMenuItem(
                icon: Icons.search,
                label: appLocalizations.search,
                onPressed: onSearch,
              ),
              CommonPopupMenuItem(
                icon: Icons.undo,
                label: appLocalizations.undo,
                onPressed: controller.canUndo ? controller.undo : null,
              ),
              CommonPopupMenuItem(
                icon: Icons.redo,
                label: appLocalizations.redo,
                onPressed: controller.canRedo ? controller.redo : null,
              ),
              CommonPopupMenuItem(
                icon: Icons.format_color_text,
                label: appLocalizations.currentLineForeground,
                onPressed: () async {
                  await _selectCurrentLineColor(context, ref, foreground: true);
                },
              ),
              CommonPopupMenuItem(
                icon: Icons.format_color_fill,
                label: appLocalizations.currentLineBackground,
                onPressed: () async {
                  await _selectCurrentLineColor(
                    context,
                    ref,
                    foreground: false,
                  );
                },
              ),
              if (supportRemoteDownload && !readOnly)
                CommonPopupMenuItem(
                  icon: Icons.arrow_downward,
                  label: appLocalizations.externalFetch,
                  subItems: [
                    CommonPopupMenuItem(
                      label: appLocalizations.importUrl,
                      onPressed: onImportFromUrl,
                    ),
                    CommonPopupMenuItem(
                      label: appLocalizations.importFile,
                      onPressed: onImportFromFile,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EditorColorSelection {
  const _EditorColorSelection(this.value);

  final int? value;
}

class _EditorColorDialog extends StatefulWidget {
  const _EditorColorDialog({required this.title, required this.initialColor});

  final String title;
  final Color initialColor;

  @override
  State<_EditorColorDialog> createState() => _EditorColorDialogState();
}

class _EditorColorDialogState extends State<_EditorColorDialog> {
  late final ValueNotifier<Color> _controller;

  @override
  void initState() {
    super.initState();
    _controller = ValueNotifier(widget.initialColor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: widget.title,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(const _EditorColorSelection(null));
          },
          child: Text(appLocalizations.reset),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(_EditorColorSelection(_controller.value.toARGB32()));
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: SizedBox(width: 300, child: Palette(controller: _controller)),
    );
  }
}

class _EditorBody extends ConsumerWidget {
  const _EditorBody({
    required this.controller,
    required this.findController,
    required this.toolbarController,
    required this.focusNode,
    required this.scrollController,
    required this.readOnly,
    required this.languages,
    required this.currentLineHighlightStyle,
    required this.isLoading,
  });

  final CodeLineEditingController controller;
  final CodeFindController findController;
  final SelectionToolbarController toolbarController;
  final FocusNode focusNode;
  final CodeScrollController scrollController;
  final bool readOnly;
  final List<Language> languages;
  final _CurrentLineHighlightStyle currentLineHighlightStyle;
  final bool isLoading;

  CodeHighlightTheme get _highlightTheme {
    return CodeHighlightTheme(
      languages: {
        if (languages.contains(Language.yaml))
          'yaml': CodeHighlightThemeMode(mode: langYaml),
        if (languages.contains(Language.javaScript))
          'javascript': CodeHighlightThemeMode(mode: langJavascript),
        if (languages.contains(Language.json))
          'json': CodeHighlightThemeMode(mode: langJson),
      },
      theme: atomOneLightTheme,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobileView = ref.watch(isMobileViewProvider);
    return Stack(
      children: [
        CodeEditor(
          readOnly: readOnly,
          autofocus: false,
          showCursorWhenReadOnly: false,
          findController: findController,
          findBuilder: (context, controller, readOnly) => FindPanel(
            controller: controller,
            readOnly: readOnly,
            isMobileView: isMobileView,
          ),
          padding: const EdgeInsets.only(right: 16),
          autocompleteSymbols: true,
          focusNode: focusNode,
          scrollController: scrollController,
          scrollbarBuilder: (context, child, details) {
            return CommonScrollBar(
              controller: details.controller,
              child: child,
            );
          },
          toolbarController: toolbarController,
          indicatorBuilder:
              (context, editingController, chunkController, notifier) {
                return _EditorGutter(
                  controller: editingController,
                  chunkController: chunkController,
                  notifier: notifier,
                );
              },
          shortcutsActivatorsBuilder:
              const DefaultCodeShortcutsActivatorsBuilder(),
          chunkAnalyzer: languages.contains(Language.yaml)
              ? const YamlCodeChunkAnalyzer()
              : const DefaultCodeChunkAnalyzer(),
          controller: controller,
          style: CodeEditorStyle(
            fontSize: context.textTheme.bodyLarge?.fontSize?.ap,
            fontFamily: FontFamily.jetBrainsMono.value,
            cursorLineColor: currentLineHighlightStyle.background,
            codeTheme: _highlightTheme,
          ),
        ),
        FadeBox(
          child: isLoading
              ? Container(
                  color: context.colorScheme.surface,
                  alignment: Alignment.center,
                  child: const SizedBox.square(
                    dimension: 200,
                    child: CommonCircleLoading(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CurrentLineHighlightStyle {
  const _CurrentLineHighlightStyle({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;

  @override
  bool operator ==(Object other) {
    return other is _CurrentLineHighlightStyle &&
        other.foreground == foreground &&
        other.background == background;
  }

  @override
  int get hashCode => Object.hash(foreground, background);
}

class YamlCodeChunkAnalyzer implements CodeChunkAnalyzer {
  const YamlCodeChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final chunks = <CodeChunk>[];
    final openChunks = <_YamlChunkStart>[];
    for (var index = 0; index < codeLines.length; index++) {
      final trimmed = codeLines[index].text.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      if (trimmed == '---' || trimmed == '...') {
        _closeOpenChunks(openChunks, chunks, index);
        continue;
      }
      final indent =
          codeLines[index].text.length -
          codeLines[index].text.trimLeft().length;
      while (openChunks.isNotEmpty && indent <= openChunks.last.indent) {
        _closeLastChunk(openChunks, chunks, index);
      }
      if (openChunks.isNotEmpty) {
        openChunks.last.hasChildren = true;
      }
      openChunks.add(_YamlChunkStart(index: index, indent: indent));
    }
    _closeOpenChunks(openChunks, chunks, codeLines.length);
    chunks.sort((a, b) => a.index.compareTo(b.index));
    return chunks;
  }

  void _closeOpenChunks(
    List<_YamlChunkStart> openChunks,
    List<CodeChunk> chunks,
    int end,
  ) {
    while (openChunks.isNotEmpty) {
      _closeLastChunk(openChunks, chunks, end);
    }
  }

  void _closeLastChunk(
    List<_YamlChunkStart> openChunks,
    List<CodeChunk> chunks,
    int end,
  ) {
    final chunk = openChunks.removeLast();
    if (chunk.hasChildren && end - chunk.index > 1) {
      chunks.add(CodeChunk(chunk.index, end));
    }
  }
}

class _YamlChunkStart {
  _YamlChunkStart({required this.index, required this.indent});

  final int index;
  final int indent;
  bool hasChildren = false;
}

class _EditorGutter extends StatelessWidget {
  const _EditorGutter({
    required this.controller,
    required this.chunkController,
    required this.notifier,
  });

  final CodeLineEditingController controller;
  final CodeChunkController chunkController;
  final CodeIndicatorValueNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DefaultCodeLineNumber(controller: controller, notifier: notifier),
        DefaultCodeChunkIndicator(
          width: 20,
          controller: chunkController,
          notifier: notifier,
        ),
      ],
    );
  }
}

const double _kDefaultFindPanelHeight = 52;

class FindPanel extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final bool readOnly;
  final bool isMobileView;
  final double height;

  const FindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.isMobileView,
  }) : height =
           (isMobileView
               ? _kDefaultFindPanelHeight * 2
               : _kDefaultFindPanelHeight) +
           8;

  @override
  Size get preferredSize =>
      Size(double.infinity, controller.value == null ? 0 : height);

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox(width: 0, height: 0);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      color: context.colorScheme.surface,
      alignment: Alignment.centerLeft,
      height: height,
      child: _buildFindInputView(context),
    );
  }

  Widget _buildFindInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    final String result;
    if (value.result == null) {
      result = context.appLocalizations.none;
    } else {
      result = '${value.result!.index + 1}/${value.result!.matches.length}';
    }
    final bar = CommonMinIconButtonTheme(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isMobileView) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _buildFindInput(context, value),
            ),
            const SizedBox(width: 12),
          ],
          Text(result, style: context.textTheme.bodyMedium),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 2,
              children: [
                _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.previousMatch();
                        },
                  icon: Icons.arrow_upward,
                  tooltip: context.appLocalizations.previousMatch,
                ),
                _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.nextMatch();
                        },
                  icon: Icons.arrow_downward,
                  tooltip: context.appLocalizations.nextMatch,
                ),
                const SizedBox(width: 2),
                IconButton.filledTonal(
                  tooltip: context.appLocalizations.close,
                  onPressed: controller.close,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (isMobileView) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          bar,
          const SizedBox(height: 12),
          _buildFindInput(context, value),
        ],
      );
    }
    return bar;
  }

  Widget _buildFindInput(BuildContext context, CodeFindValue value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 8,
      children: [
        Flexible(
          child: _buildTextField(
            context: context,
            onSubmitted: () {
              if (value.result == null) {
                return;
              }
              controller.nextMatch();
              controller.findInputFocusNode.requestFocus();
            },
            controller: controller.findInputController,
            focusNode: controller.findInputFocusNode,
          ),
        ),
        _buildCheckText(
          context: context,
          text: 'Aa',
          isSelected: value.option.caseSensitive,
          onPressed: () {
            controller.toggleCaseSensitive();
          },
        ),
        _buildCheckText(
          context: context,
          text: '.*',
          isSelected: value.option.regex,
          onPressed: () {
            controller.toggleRegex();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onSubmitted,
  }) {
    return SizedBox(
      height: globalState.measure.bodyMediumHeight + 8 * 2,
      child: TextField(
        maxLines: 1,
        focusNode: focusNode,
        inputFormatters: TextInputLimits.limit(TextInputLimits.search),
        style: context.textTheme.bodyMedium,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        onSubmitted: (_) {
          onSubmitted();
        },
        controller: controller,
      ),
    );
  }

  Widget _buildCheckText({
    required BuildContext context,
    required String text,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: isSelected
            ? IconButton.filledTonal(
                onPressed: onPressed,
                padding: const EdgeInsets.all(2),
                icon: Text(text, style: context.textTheme.bodySmall),
              )
            : IconButton(
                onPressed: onPressed,
                padding: const EdgeInsets.all(2),
                icon: Text(text, style: context.textTheme.bodySmall),
              ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
    );
  }
}

class ContextMenuControllerImpl implements SelectionToolbarController {
  OverlayEntry? _overlayEntry;
  bool _isFirstRender = true;
  bool readOnly = false;

  ContextMenuControllerImpl(this.readOnly);

  void _removeOverLayEntry() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isFirstRender = true;
  }

  @override
  void hide(BuildContext context) {
    _removeOverLayEntry();
  }

  @override
  void show({
    required context,
    required controller,
    required anchors,
    renderRect,
    required layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _removeOverLayEntry();
    _overlayEntry ??= OverlayEntry(
      builder: (context) => CodeEditorTapRegion(
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, _, child) {
            final appLocalizations = context.appLocalizations;
            final isNotEmpty = controller.selectedText.isNotEmpty;
            final isAllSelected = controller.isAllSelected;
            final hasSelected = controller.selectedText.isNotEmpty;
            final List<CommonPopupMenuItem> menus = [
              if (isNotEmpty)
                CommonPopupMenuItem(
                  label: appLocalizations.copy,
                  onPressed: controller.copy,
                ),
              if (!readOnly)
                CommonPopupMenuItem(
                  label: appLocalizations.paste,
                  onPressed: controller.paste,
                ),
              if (isNotEmpty && !readOnly)
                CommonPopupMenuItem(
                  label: appLocalizations.cut,
                  onPressed: controller.cut,
                ),
              if (hasSelected && !isAllSelected)
                CommonPopupMenuItem(
                  label: appLocalizations.selectAll,
                  onPressed: controller.selectAll,
                ),
            ];
            if (_isFirstRender) {
              _isFirstRender = false;
            } else if (controller.selectedText.isEmpty) {
              _removeOverLayEntry();
            }
            if (menus.isEmpty) {
              _removeOverLayEntry();
              return const SizedBox();
            }
            return TextSelectionToolbar(
              anchorAbove: anchors.primaryAnchor,
              anchorBelow: anchors.secondaryAnchor ?? Offset.zero,
              children: menus.asMap().entries.map((
                MapEntry<int, CommonPopupMenuItem> entry,
              ) {
                return TextSelectionToolbarTextButton(
                  padding: TextSelectionToolbarTextButton.getPadding(
                    entry.key,
                    menus.length,
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  onPressed: () {
                    if (entry.value.onPressed == null) {
                      return;
                    }
                    entry.value.onPressed!();
                    _removeOverLayEntry();
                  },
                  child: Text(entry.value.label),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }
}
