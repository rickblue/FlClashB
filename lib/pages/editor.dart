import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

typedef EditingValueChangeBuilder = Widget Function(CodeLineEditingValue value);
typedef TextEditingValueChangeBuilder = Widget Function(TextEditingValue value);

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
  late bool readOnly = false;
  late final SelectionToolbarController _toolbarController;

  @override
  void initState() {
    super.initState();
    readOnly = widget.onSave == null;
    _toolbarController = ContextMenuControllerImpl(readOnly);
    _focusNode = FocusNode();
    _controller = CodeLineEditingController.fromText(widget.content);
    _findController = CodeFindController(_controller);
    _titleController = TextEditingController(text: widget.title);
    _scrollController = CodeScrollController();
    _focusNode.onKeyEvent = ((_, event) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final key = event.logicalKey;
      if (!keys.contains(key)) {
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.pageUp) {
        _moveCursorByPage(false);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.pageDown) {
        _moveCursorByPage(true);
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
    });
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
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _wrapController(EditingValueChangeBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (_, value, _) {
        return builder(value);
      },
    );
  }

  Widget _wrapTitleController(TextEditingValueChangeBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _titleController,
      builder: (_, value, _) {
        return builder(value);
      },
    );
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
    _controller.text = res;
  }

  Future<void> _handleImportFormUrl() async {
    final appLocalizations = context.appLocalizations;
    final url = await globalState.showCommonDialog(
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
    final res = await request.getTextResponseForUrl(url);
    _controller.text = res.data ?? '';
  }

  bool get _isYamlEditor => widget.languages.contains(Language.yaml);

  void _moveCursorByPage(bool forward) {
    if (!_scrollController.verticalScroller.hasClients) {
      return;
    }
    final position = _scrollController.verticalScroller.position;
    final fontSize = context.textTheme.bodyLarge?.fontSize?.ap ?? 13;
    final lineHeight = (fontSize * 1.5).clamp(18, 48).toDouble();
    final pageExtent = (position.viewportDimension - lineHeight)
        .clamp(lineHeight, double.infinity)
        .toDouble();
    final lineDelta = (pageExtent / lineHeight).floor().clamp(1, 9999).toInt();
    final selection = _controller.selection;
    final currentIndex = selection.extentIndex;
    final targetIndex =
        (forward ? currentIndex + lineDelta : currentIndex - lineDelta)
            .clamp(0, _controller.lineCount - 1)
            .toInt();
    final targetLine = _controller.codeLines[targetIndex];
    final targetOffset = selection.extentOffset
        .clamp(0, targetLine.length)
        .toInt();
    final targetPixels =
        (forward ? position.pixels + pageExtent : position.pixels - pageExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();

    _controller.selection = CodeLineSelection.collapsed(
      index: targetIndex,
      offset: targetOffset,
    );
    position.jumpTo(targetPixels);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isMobileView = ref.watch(isMobileViewProvider);
    return CommonPopScope(
      onPop: (context) async {
        if (widget.onPop == null) {
          return true;
        }
        final res = await widget.onPop!(
          context,
          _titleController.text,
          _controller.text,
        );
        if (res && context.mounted) {
          return true;
        }
        return false;
      },
      child: CommonScaffold(
        appBar: AppBar(
          title: TextField(
            maxLength: 20,
            enabled: widget.titleEditable,
            controller: _titleController,
            decoration: InputDecoration(
              border: const NoInputBorder(),
              counter: const SizedBox(),
              hintText: appLocalizations.unnamed,
            ),
            style: context.textTheme.titleLarge,
            autofocus: false,
          ),
          actions: genActions([
            if (!readOnly)
              _wrapController(
                (value) => _wrapTitleController(
                  (value) => IconButton(
                    onPressed:
                        _controller.text != widget.content ||
                            _titleController.text != widget.title
                        ? () {
                            widget.onSave!(
                              context,
                              _titleController.text,
                              _controller.text,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.save),
                  ),
                ),
              ),
            _wrapController(
              (value) => CommonPopupBox(
                targetBuilder: (open) {
                  return IconButton(
                    onPressed: () {
                      final isMobile = ref.read(isMobileViewProvider);
                      open(offset: Offset(0, isMobile ? 0 : 20));
                    },
                    icon: const Icon(Icons.more_vert),
                  );
                },
                popup: CommonPopupMenu(
                  items: [
                    PopupMenuItemData(
                      icon: Icons.search,
                      label: appLocalizations.search,
                      onPressed: _handleSearch,
                    ),
                    PopupMenuItemData(
                      icon: Icons.undo,
                      label: appLocalizations.undo,
                      onPressed: _controller.canUndo ? _controller.undo : null,
                    ),
                    PopupMenuItemData(
                      icon: Icons.redo,
                      label: appLocalizations.redo,
                      onPressed: _controller.canRedo ? _controller.redo : null,
                    ),
                    if (widget.supportRemoteDownload && !readOnly)
                      PopupMenuItemData(
                        icon: Icons.arrow_downward,
                        label: appLocalizations.externalFetch,
                        subItems: [
                          PopupMenuItemData(
                            label: appLocalizations.importUrl,
                            onPressed: _handleImportFormUrl,
                          ),
                          PopupMenuItemData(
                            label: appLocalizations.importFile,
                            onPressed: _handleImportFormFile,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),
        body: CodeEditor(
          readOnly: readOnly,
          autofocus: false,
          scrollController: _scrollController,
          findController: _findController,
          findBuilder: (context, controller, readOnly) => FindPanel(
            controller: controller,
            readOnly: readOnly,
            isMobileView: isMobileView,
          ),
          padding: EdgeInsets.only(right: 16),
          autocompleteSymbols: true,
          focusNode: _focusNode,
          scrollbarBuilder: (context, child, details) {
            return CommonScrollBar(
              controller: details.controller,
              child: child,
            );
          },
          toolbarController: _toolbarController,
          indicatorBuilder:
              (context, editingController, chunkController, notifier) {
                return Row(
                  children: [
                    DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                    ),
                    DefaultCodeChunkIndicator(
                      width: 20,
                      controller: chunkController,
                      notifier: notifier,
                    ),
                  ],
                );
              },
          shortcutsActivatorsBuilder: DefaultCodeShortcutsActivatorsBuilder(),
          chunkAnalyzer: _isYamlEditor ? const YamlCodeChunkAnalyzer() : null,
          controller: _controller,
          style: CodeEditorStyle(
            fontSize: context.textTheme.bodyLarge?.fontSize?.ap,
            fontFamily: FontFamily.jetBrainsMono.value,
            codeTheme: CodeHighlightTheme(
              languages: {
                if (widget.languages.contains(Language.yaml))
                  'yaml': CodeHighlightThemeMode(mode: langYaml),
                if (widget.languages.contains(Language.javaScript))
                  'javascript': CodeHighlightThemeMode(mode: langJavascript),
                if (widget.languages.contains(Language.json))
                  'json': CodeHighlightThemeMode(mode: langJson),
              },
              theme: atomOneLightTheme,
            ),
          ),
        ),
      ),
    );
  }
}

class YamlCodeChunkAnalyzer implements CodeChunkAnalyzer {
  const YamlCodeChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final chunks = <CodeChunk>[];
    final stack = <_YamlChunkState>[];
    _YamlLineState? previous;

    for (var index = 0; index < codeLines.length; index++) {
      final current = _parseLine(index, codeLines[index].text);
      if (current == null) {
        continue;
      }

      while (stack.isNotEmpty && current.indent <= stack.last.indent) {
        final chunk = stack.removeLast().toChunk(current.index);
        if (chunk != null) {
          chunks.add(chunk);
        }
      }

      if (previous != null && current.indent > previous.indent) {
        stack.add(_YamlChunkState(previous.index, previous.indent));
      }

      previous = current;
    }

    while (stack.isNotEmpty) {
      final chunk = stack.removeLast().toChunk(codeLines.length);
      if (chunk != null) {
        chunks.add(chunk);
      }
    }

    chunks.sort((a, b) => a.index.compareTo(b.index));
    return chunks;
  }

  _YamlLineState? _parseLine(int index, String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      return null;
    }
    return _YamlLineState(index: index, indent: _indentOf(text));
  }

  int _indentOf(String text) {
    var indent = 0;
    for (final rune in text.runes) {
      if (rune == 0x20) {
        indent++;
      } else if (rune == 0x09) {
        indent += 2;
      } else {
        break;
      }
    }
    return indent;
  }
}

class _YamlLineState {
  final int index;
  final int indent;

  const _YamlLineState({required this.index, required this.indent});
}

class _YamlChunkState {
  final int index;
  final int indent;

  const _YamlChunkState(this.index, this.indent);

  CodeChunk? toChunk(int end) {
    if (end - index <= 1) {
      return null;
    }
    return CodeChunk(index, end);
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
                ),
                _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.nextMatch();
                        },
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(width: 2),
                IconButton.filledTonal(
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
          border: OutlineInputBorder(),
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

  Widget _buildIconButton({required IconData icon, VoidCallback? onPressed}) {
    return IconButton(onPressed: onPressed, icon: Icon(icon, size: 16));
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
            final List<PopupMenuItemData> menus = [
              if (isNotEmpty)
                PopupMenuItemData(
                  label: appLocalizations.copy,
                  onPressed: controller.copy,
                ),
              if (!readOnly)
                PopupMenuItemData(
                  label: appLocalizations.paste,
                  onPressed: controller.paste,
                ),
              if (isNotEmpty && !readOnly)
                PopupMenuItemData(
                  label: appLocalizations.cut,
                  onPressed: controller.cut,
                ),
              if (hasSelected && !isAllSelected)
                PopupMenuItemData(
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
                MapEntry<int, PopupMenuItemData> entry,
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

class _ImportOptionsDialog extends StatefulWidget {
  const _ImportOptionsDialog();

  @override
  State<_ImportOptionsDialog> createState() => _ImportOptionsDialogState();
}

class _ImportOptionsDialogState extends State<_ImportOptionsDialog> {
  void _handleOnTab(ImportOption value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.import,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              _handleOnTab(ImportOption.url);
            },
            title: Text(appLocalizations.importUrl),
          ),
          ListItem(
            onTap: () {
              _handleOnTab(ImportOption.file);
            },
            title: Text(appLocalizations.importFile),
          ),
        ],
      ),
    );
  }
}
