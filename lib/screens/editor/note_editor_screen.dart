import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/font_constants.dart';
import '../../core/utils/text_utils.dart';
import '../../models/note.dart';
import '../../providers/background_provider.dart';
import '../../providers/folder_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/page_style_provider.dart';
import '../../core/constants/theme_constants.dart';
import '../../services/note_service.dart';
import '../../widgets/common/app_background.dart';
import '../../widgets/editor/sticker_panel.dart';
import '../../screens/gif/gif_picker_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'audio_embed_builder.dart';
import 'drawing_canvas_screen.dart';
import 'image_embed_builder.dart';
import '../../services/activity_log_service.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final int? noteId;
  final int folderId;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    required this.folderId,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  QuillController? _controller;       // null until _initEditor completes
  late ScrollController _scrollController;
  late FocusNode _focusNode;
  late TextEditingController _titleController;
  Note? _existingNote;

  Timer? _debounceTimer;
  bool _isSaving = false;
  bool _editorReady = false;          // shows spinner until editor is ready
  bool _advancedToolbar = false;      // false = basic toolbar (B/I/U/H), true = full
  int _wordCount = 0;
  NoteFont _currentFont = NoteFont.merriweather;
  _PageLayout _pageLayout = _PageLayout.textOnly;
  List<String> _layoutImages = [];
  String? _noteBgPresetId;
  String? _noteBgImagePath;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _titleController = TextEditingController();
    _currentFont = ref.read(fontProvider);
    _initEditor();
  }

  // Builds the QuillController exactly ONCE, then sets _editorReady = true.
  // We never swap _controller after the first build — that causes the
  // _elements.contains(element) assertion in Flutter's framework.
  Future<void> _initEditor() async {
    QuillController controller;
    NoteFont font = _currentFont;

    if (widget.noteId != null) {
      final note = await NoteService.getNoteById(widget.noteId!);
      if (!mounted) return;

      if (note != null) {
        final masterKey = ref.read(masterKeyProvider);
        if (masterKey != null) {
          final deltaJson = NoteService.decryptBody(note, masterKey);
          final doc = Document.fromJson(jsonDecode(deltaJson) as List);
          controller = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
          _existingNote = note;
          // Sanitize any legacy titles that contain literal \n characters
          // (caused by old _extractPlainText bug returning JSON-escaped text).
          _titleController.text = note.title
              .replaceAll('\n', ' ')
              .replaceAll('\r', '')
              .trim();
          _wordCount = note.wordCount;
          font = noteFontFromString(note.fontFamily);
          _pageLayout = _PageLayout.fromString(note.pageLayout);
          _layoutImages = List<String>.from(note.layoutImages);
          _noteBgPresetId = note.noteBgPresetId;
          _noteBgImagePath = note.noteBgImagePath;
        } else {
          controller = QuillController.basic();
        }
      } else {
        controller = QuillController.basic();
      }
    } else {
      controller = QuillController.basic();
    }

    controller.addListener(_onDocumentChanged);

    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _currentFont = font;
      _editorReady = true;
    });

    // Open the keyboard immediately after the editor is laid out.
    // Without this, the user has to tap the text area first — causing the
    // visible lag/delay before the keyboard appears on a new entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onDocumentChanged() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final plainText = ctrl.document.toPlainText();
    final count = TextUtils.countWords(plainText);
    if (count != _wordCount) {
      setState(() => _wordCount = count);
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: AppConstants.autoSaveDebounceMs),
      _autoSave,
    );
  }

  Future<void> _autoSave() async {
    if (_isSaving || _controller == null) return;
    setState(() => _isSaving = true);
    await _save();
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _save() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;

    final deltaJson = jsonEncode(ctrl.document.toDelta().toJson());
    final title = _titleController.text.trim();

    if (_existingNote == null) {
      final created = await NoteService.createNote(
        title: title,
        deltaJson: deltaJson,
        masterKey: masterKey,
        folderId: widget.folderId,
        fontFamily: _currentFont.label,
        pageLayout: _pageLayout.value,
        layoutImages: _layoutImages,
        noteBgPresetId: _noteBgPresetId,
        noteBgImagePath: _noteBgImagePath,
      );
      ActivityLogService.log(
        sessionType: 'local',
        noteId: created.id.toString(),
        action: 'created',
        noteTitle: created.title,
      );
      if (mounted) {
        setState(() {
          _existingNote = created;
          if (title.isEmpty) _titleController.text = created.title;
        });
      }
    } else {
      final updated = await NoteService.updateNote(
        note: _existingNote!,
        deltaJson: deltaJson,
        masterKey: masterKey,
        title: title.isEmpty ? null : title,
        fontFamily: _currentFont.label,
        pageLayout: _pageLayout.value,
        layoutImages: _layoutImages,
        noteBgPresetId: _noteBgPresetId,
        noteBgImagePath: _noteBgImagePath,
      );
      ActivityLogService.log(
        sessionType: 'local',
        noteId: _existingNote!.id.toString(),
        action: 'edited',
        noteTitle: title.isNotEmpty ? title : _existingNote!.title,
      );
      if (mounted) setState(() => _existingNote = updated);
    }

    ref.invalidate(notesProvider);
    ref.invalidate(foldersProvider);
  }

  Future<void> _onDone() async {
    _debounceTimer?.cancel();
    await _save();
    if (mounted) context.pop();
  }

  // ── Emoji picker ────────────────────────────────────────────────────────────
  void _openEmojiPicker() {
    final ctrl = _controller;
    if (ctrl == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 280,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            Navigator.pop(context);
            final index = ctrl.selection.isValid
                ? ctrl.selection.extentOffset
                : ctrl.document.length - 1;
            ctrl.document.insert(index, emoji.emoji);
            ctrl.updateSelection(
              TextSelection.collapsed(offset: index + emoji.emoji.length),
              ChangeSource.local,
            );
          },
          config: const Config(),
        ),
      ),
    );
  }

  // ── Sticker panel ───────────────────────────────────────────────────────────
  void _openStickerPanel() {
    final ctrl = _controller;
    if (ctrl == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StickerPanel(
        onSticker: (sticker) {
          // StickerPanel already calls Navigator.pop; insert after sheet closes.
          final index = ctrl.selection.isValid
              ? ctrl.selection.extentOffset
              : ctrl.document.length - 1;
          ctrl.document.insert(index, sticker);
          ctrl.updateSelection(
            TextSelection.collapsed(offset: index + sticker.length),
            ChangeSource.local,
          );
        },
      ),
    );
  }

  // ── GIF picker ──────────────────────────────────────────────────────────────
  Future<void> _openGifPicker() async {
    if (_controller == null) return;
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const GifPickerScreen()),
    );
    if (url == null || !mounted) return;
    final ctrl = _controller;
    if (ctrl == null) return;

    final index = ctrl.selection.isValid
        ? ctrl.selection.extentOffset
        : ctrl.document.length - 1;
    ctrl.document.insert(index, BlockEmbed.image(url));
    ctrl.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      ChangeSource.local,
    );
    await _autoSave();
  }

  // ── Layout picker ───────────────────────────────────────────────────────────
  void _openLayoutPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LayoutPickerSheet(
        current: _pageLayout,
        images: _layoutImages,
        onSelect: (layout) async {
          Navigator.pop(context);
          if (layout == _pageLayout) return;
          // When switching to image-requiring layouts, pick images immediately
          if (layout == _PageLayout.imageSide || layout == _PageLayout.collage) {
            final max = layout == _PageLayout.collage ? 4 : 1;
            final picked = await _pickLayoutImages(max);
            if (picked.isEmpty && mounted) return; // user cancelled
            setState(() {
              _pageLayout = layout;
              _layoutImages = picked;
            });
          } else {
            setState(() {
              _pageLayout = layout;
              _layoutImages = [];
            });
          }
          _autoSave();
        },
        onAddImage: () async {
          final max = _pageLayout == _PageLayout.collage ? 4 : 1;
          final picked = await _pickLayoutImages(max);
          if (picked.isNotEmpty && mounted) {
            setState(() => _layoutImages = picked);
            _autoSave();
          }
        },
      ),
    );
  }

  Future<List<String>> _pickLayoutImages(int maxCount) async {
    final picker = ImagePicker();
    if (maxCount == 1) {
      final file = await picker.pickImage(source: ImageSource.gallery);
      return file == null ? [] : [file.path];
    } else {
      final files = await picker.pickMultiImage(limit: maxCount);
      return files.map((f) => f.path).toList();
    }
  }

  // ── Font picker ─────────────────────────────────────────────────────────────
  void _openFontPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FontPickerSheet(
        current: _currentFont,
        onSelect: (font) {
          Navigator.pop(context);
          setState(() => _currentFont = font);
          _autoSave();
        },
      ),
    );
  }

  // ── Entry background picker ─────────────────────────────────────────────────
  void _openEntryBgPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EntryBgPickerSheet(
        currentPresetId: _noteBgPresetId,
        currentImagePath: _noteBgImagePath,
        onPreset: (presetId) {
          Navigator.pop(context);
          setState(() {
            _noteBgPresetId = presetId;
            _noteBgImagePath = null;
          });
          _autoSave();
        },
        onImage: (path) {
          Navigator.pop(context);
          setState(() {
            _noteBgImagePath = path;
            _noteBgPresetId = null;
          });
          _autoSave();
        },
        onClear: () {
          Navigator.pop(context);
          setState(() {
            _noteBgPresetId = null;
            _noteBgImagePath = null;
          });
          _autoSave();
        },
      ),
    );
  }

  // ── Audio recorder ──────────────────────────────────────────────────────────
  void _openAudioRecorder() {
    if (_controller == null) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AudioRecorderSheet(
        onDone: (path) {
          Navigator.pop(context);
          if (path == null || !mounted) return;
          final ctrl = _controller;
          if (ctrl == null) return;
          final index = ctrl.selection.isValid
              ? ctrl.selection.extentOffset
              : ctrl.document.length - 1;
          ctrl.document.insert(index, BlockEmbed(kAudioEmbedKey, path));
          ctrl.updateSelection(
            TextSelection.collapsed(offset: index + 1),
            ChangeSource.local,
          );
          _autoSave();
        },
      ),
    );
  }

  // ── Drawing canvas ──────────────────────────────────────────────────────────
  Future<void> _openDrawingCanvas() async {
    if (_controller == null) return;
    final filePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const DrawingCanvasScreen()),
    );
    if (filePath == null || !mounted) return;
    final ctrl = _controller;
    if (ctrl == null) return;

    final index = ctrl.selection.isValid
        ? ctrl.selection.extentOffset
        : ctrl.document.length - 1;
    ctrl.document.insert(index, BlockEmbed.image(filePath));
    ctrl.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      ChangeSource.local,
    );
    await _autoSave();
  }

  // ── Formatting help ─────────────────────────────────────────────────────────
  void _showFormattingHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FormattingHelpSheet(),
    );
  }

  // ── Insert & style sheet ────────────────────────────────────────────────────
  // Single entry point for all non-text-formatting actions.
  // Replaces the old cluttered AppBar icons + popup menu.
  void _showInsertSheet(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // RECORD
              _SheetSection(label: 'RECORD', colors: colors),
              _SheetRow(children: [
                _SheetItem(
                  icon: Icons.mic_rounded,
                  label: 'Voice note',
                  color: colors.primary,
                  onTap: () { Navigator.pop(context); _openAudioRecorder(); },
                ),
                _SheetItem(
                  icon: Icons.draw_outlined,
                  label: 'Drawing',
                  color: colors.primary,
                  onTap: () { Navigator.pop(context); _openDrawingCanvas(); },
                ),
              ]),
              const SizedBox(height: 12),

              // INSERT
              _SheetSection(label: 'INSERT', colors: colors),
              _SheetRow(children: [
                _SheetItem(
                  icon: Icons.emoji_emotions_outlined,
                  label: 'Emoji',
                  color: colors.secondary,
                  onTap: () { Navigator.pop(context); _openEmojiPicker(); },
                ),
                _SheetItem(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Sticker',
                  color: colors.secondary,
                  onTap: () { Navigator.pop(context); _openStickerPanel(); },
                ),
                _SheetItem(
                  icon: Icons.gif_box_outlined,
                  label: 'GIF',
                  color: colors.secondary,
                  onTap: () { Navigator.pop(context); _openGifPicker(); },
                ),
              ]),
              const SizedBox(height: 12),

              // STYLE
              _SheetSection(label: 'STYLE', colors: colors),
              _SheetRow(children: [
                _SheetItem(
                  icon: Icons.text_fields_rounded,
                  label: 'Font\n${_currentFont.label}',
                  color: colors.tertiary,
                  onTap: () { Navigator.pop(context); _openFontPicker(); },
                ),
                _SheetItem(
                  icon: Icons.wallpaper_outlined,
                  label: 'Background',
                  color: colors.tertiary,
                  badge: _noteBgPresetId != null || _noteBgImagePath != null,
                  onTap: () { Navigator.pop(context); _openEntryBgPicker(); },
                ),
                _SheetItem(
                  icon: _pageLayout == _PageLayout.textOnly
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_rounded,
                  label: 'Layout\n${_pageLayout.label}',
                  color: colors.tertiary,
                  onTap: () { Navigator.pop(context); _openLayoutPicker(); },
                ),
              ]),
              const SizedBox(height: 12),

              // HELP
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.help_outline, color: colors.outline),
                title: Text('Formatting guide',
                    style: TextStyle(color: colors.onSurface, fontSize: 14)),
                trailing: Icon(Icons.chevron_right, color: colors.outline),
                onTap: () {
                  Navigator.pop(context);
                  _showFormattingHelp(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller?.removeListener(_onDocumentChanged);
    _controller?.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onDone,
        ),
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Entry title…',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _autoSave(),
        ),
        actions: [
          // Subtle autosave indicator
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
              ),
            ),
          // Single ⊕ button — opens the organized insert & style sheet
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colors.primary),
            tooltip: 'Insert & style',
            onPressed: () => _showInsertSheet(context),
          ),
          TextButton(
            onPressed: _onDone,
            child: const Text('Done'),
          ),
        ],
      ),
      body: _EditorBackgroundWrapper(
        noteBgPresetId: _noteBgPresetId,
        noteBgImagePath: _noteBgImagePath,
        child: !_editorReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Minimal formatting toolbar + expand/collapse toggle ──
                // Shows B/I/U/H always. Chevron at right reveals advanced options.
                Row(
                  children: [
                    Expanded(
                      child: QuillSimpleToolbar(
                        controller: _controller!,
                        config: QuillSimpleToolbarConfig(
                          showFontFamily: false,
                          showFontSize: false,
                          showBackgroundColorButton: _advancedToolbar,
                          showClearFormat: _advancedToolbar,
                          showColorButton: _advancedToolbar,
                          showBoldButton: true,
                          showItalicButton: true,
                          showUnderLineButton: true,
                          showStrikeThrough: _advancedToolbar,
                          showHeaderStyle: true,
                          showListNumbers: _advancedToolbar,
                          showListBullets: _advancedToolbar,
                          showQuote: _advancedToolbar,
                          showAlignmentButtons: _advancedToolbar,
                          showCodeBlock: false,
                          showInlineCode: false,
                          showLink: _advancedToolbar,
                          showSearchButton: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showIndent: _advancedToolbar,
                          showUndo: _advancedToolbar,
                          showRedo: _advancedToolbar,
                        ),
                      ),
                    ),
                    // Expand/collapse formatting options
                    Tooltip(
                      message: _advancedToolbar
                          ? 'Less formatting'
                          : 'More formatting',
                      child: InkWell(
                        onTap: () =>
                            setState(() => _advancedToolbar = !_advancedToolbar),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Icon(
                            _advancedToolbar
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: _advancedToolbar
                                ? colors.primary
                                : colors.outline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),

                // ── Layout image strip (image_side / collage) ──
                if (_pageLayout != _PageLayout.textOnly)
                  _LayoutImageStrip(
                    layout: _pageLayout,
                    images: _layoutImages,
                    onTap: _openLayoutPicker,
                  ),

                // ── Editor body ──
                // DefaultTextStyle.merge preserves the inherited color — safe
                // to use with google_fonts which returns TextStyle(color: null).
                // Explicit QuillEditor with lifecycle-managed ScrollController
                // and FocusNode avoids element tree instability on rebuilds.
                Expanded(
                  child: Stack(
                    children: [
                      // Page texture (controlled from Settings › Appearance)
                      CustomPaint(
                        painter: _EditorTexturePainter(
                          style: ref.watch(pageStyleProvider),
                          lineColor: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: DefaultTextStyle.merge(
                          style: noteFontStyle(_currentFont, fontSize: 16),
                          child: QuillEditor(
                            controller: _controller!,
                            scrollController: _scrollController,
                            focusNode: _focusNode,
                            config: const QuillEditorConfig(
                              placeholder: "What's on your mind today?",
                              padding: EdgeInsets.only(top: 8),
                              embedBuilders: [
                                LocalImageEmbedBuilder(),
                                AudioEmbedBuilder(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Word count bar ──
                _WordCountBar(wordCount: _wordCount, isSaving: _isSaving),
              ],
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Insert sheet helper widgets
// ─────────────────────────────────────────────
class _SheetSection extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  const _SheetSection({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: colors.outline,
          ),
        ),
      );
}

class _SheetRow extends StatelessWidget {
  final List<Widget> children;
  const _SheetRow({required this.children});

  @override
  Widget build(BuildContext context) => Row(
        children: children.map((c) => Expanded(child: c)).toList(),
      );
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool badge;

  const _SheetItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface,
                  height: 1.3),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Editor background wrapper — applies note-specific bg immediately on change.
// Falls back to the global AppBackground when no note override is set.
// ─────────────────────────────────────────────
class _EditorBackgroundWrapper extends ConsumerWidget {
  final String? noteBgPresetId;
  final String? noteBgImagePath;
  final Widget child;

  const _EditorBackgroundWrapper({
    required this.noteBgPresetId,
    required this.noteBgImagePath,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalBg = ref.watch(backgroundProvider);
    final effective = resolveNoteBackground(
      noteBgPresetId: noteBgPresetId,
      noteBgImagePath: noteBgImagePath,
      journalOrGlobalBackground: globalBg,
    );

    switch (effective.type) {
      case AppBackgroundType.image:
        if (effective.imagePath != null && File(effective.imagePath!).existsSync()) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(effective.imagePath!), fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.12)),
              child,
            ],
          );
        }
        return AppBackgroundWrapper(child: child);
      case AppBackgroundType.gradient:
        final gradColors = effective.gradientColors ??
            [const Color(0xFFF9F7F4), const Color(0xFFEEEEEE)];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradColors,
            ),
          ),
          child: child,
        );
      case AppBackgroundType.color:
        return Container(
          color: effective.color ?? const Color(0xFFF9F7F4),
          child: child,
        );
    }
  }
}


// ─────────────────────────────────────────────
// Page Layout enum
// ─────────────────────────────────────────────
enum _PageLayout {
  textOnly('text_only', 'Text only'),
  imageSide('image_side', 'Image header'),
  collage('collage', 'Collage');

  final String value;
  final String label;
  const _PageLayout(this.value, this.label);

  static _PageLayout fromString(String s) => switch (s) {
    'image_side' => _PageLayout.imageSide,
    'collage'    => _PageLayout.collage,
    _            => _PageLayout.textOnly,
  };
}

// ─────────────────────────────────────────────
// Font Picker Bottom Sheet
// ─────────────────────────────────────────────
class _FontPickerSheet extends StatelessWidget {
  final NoteFont current;
  final void Function(NoteFont) onSelect;

  const _FontPickerSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ENTRY FONT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...NoteFont.values.map((font) {
              final isSelected = font == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: isSelected
                    ? Icon(Icons.check_circle_rounded, color: colors.primary)
                    : Icon(Icons.circle_outlined, color: colors.outlineVariant),
                title: Text(
                  font.label,
                  style: noteFontStyle(font, fontSize: 16),
                ),
                subtitle: Text(
                  font.description,
                  style: TextStyle(fontSize: 12, color: colors.outline),
                ),
                onTap: () => onSelect(font),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Formatting Help Bottom Sheet
// ─────────────────────────────────────────────
class _FormattingHelpSheet extends StatelessWidget {
  const _FormattingHelpSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Writing guide',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _SectionHeader(label: 'Toolbar — tap to format', colors: colors),
              const SizedBox(height: 8),
              ..._toolbarItems(colors),
              const SizedBox(height: 24),
              _SectionHeader(label: 'Stylus & handwriting gestures', colors: colors),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Text(
                  'Available on devices with a stylus or when Android handwriting is enabled. '
                  'Hold your stylus over the text area to activate.',
                  style: TextStyle(fontSize: 12, color: colors.outline),
                ),
              ),
              ..._stylusItems(colors),
              const SizedBox(height: 24),
              _SectionHeader(label: 'Tips', colors: colors),
              const SizedBox(height: 8),
              ..._tips(colors),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _toolbarItems(ColorScheme colors) => [
    _HelpRow(icon: Icons.format_bold,         label: 'Bold',            hint: 'Select text → tap B. Great for emphasis.',                  colors: colors),
    _HelpRow(icon: Icons.format_italic,        label: 'Italic',          hint: 'Select text → tap I. For thoughts, titles, or quotes.',      colors: colors),
    _HelpRow(icon: Icons.format_underline,     label: 'Underline',       hint: 'Select text → tap U. Highlight key words.',                  colors: colors),
    _HelpRow(icon: Icons.format_color_text,    label: 'Text colour',     hint: 'Select text → pick a colour from the palette.',              colors: colors),
    _HelpRow(icon: Icons.title,                label: 'Heading 1',       hint: 'Large title for a new section.',                             colors: colors),
    _HelpRow(icon: Icons.text_fields,          label: 'Heading 2 / 3',   hint: 'Smaller sub-headings to structure your entry.',              colors: colors),
    _HelpRow(icon: Icons.format_list_bulleted, label: 'Bullet list',     hint: 'Unordered list — quick thoughts, items, or feelings.',       colors: colors),
    _HelpRow(icon: Icons.format_list_numbered, label: 'Numbered list',   hint: 'Ordered list — steps, priorities, or plans.',                colors: colors),
    _HelpRow(icon: Icons.format_quote,         label: 'Blockquote',      hint: 'Indent as a quote or a reflective aside.',                   colors: colors),
    _HelpRow(icon: Icons.undo,                 label: 'Undo / Redo',     hint: 'Step backward or forward through your changes.',             colors: colors),
  ];

  List<Widget> _stylusItems(ColorScheme colors) => [
    _HelpRow(icon: Icons.gesture,              label: 'Zig-zag to delete',      hint: 'Scribble a zig-zag over a word to erase it instantly.',       colors: colors),
    _HelpRow(icon: Icons.horizontal_rule,      label: 'Strike to remove',       hint: 'Draw a straight horizontal line through text to delete it.',   colors: colors),
    _HelpRow(icon: Icons.text_format,          label: 'Circle to select',       hint: 'Draw a circle around words to select them.',                  colors: colors),
    _HelpRow(icon: Icons.add,                  label: 'Caret to insert',        hint: 'Draw a caret (^) between words to insert a space or line.',    colors: colors),
    _HelpRow(icon: Icons.draw,                 label: 'Write to type',          hint: 'Handwrite directly in the editor — Android converts to text.', colors: colors),
  ];

  List<Widget> _tips(ColorScheme colors) => [
    _TipRow(text: 'Your entry saves automatically 1.5 seconds after you stop typing.', colors: colors),
    _TipRow(text: 'The title field at the top is editable — tap it to give your entry a custom name.', colors: colors),
    _TipRow(text: 'Leave the title blank and Hush will auto-generate it from your first line.', colors: colors),
    _TipRow(text: 'Word count and reading time update in real time at the bottom.', colors: colors),
  ];
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  const _SectionHeader({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: colors.primary,
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final ColorScheme colors;
  const _HelpRow({required this.icon, required this.label, required this.hint, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(hint, style: TextStyle(fontSize: 12, color: colors.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  final ColorScheme colors;
  const _TipRow({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: colors.onSurface)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Layout Image Strip (shown above editor in image_side / collage modes)
// ─────────────────────────────────────────────
class _LayoutImageStrip extends StatelessWidget {
  final _PageLayout layout;
  final List<String> images;
  final VoidCallback onTap;

  const _LayoutImageStrip({
    required this.layout,
    required this.images,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = layout == _PageLayout.collage ? 160.0 : 180.0;

    if (images.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          color: colors.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: colors.outline, size: 32),
                const SizedBox(height: 6),
                Text('Tap to add images',
                    style: TextStyle(color: colors.outline, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    if (layout == _PageLayout.imageSide) {
      // Single image header
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.file(
            File(images.first),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colors.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, color: colors.outline),
            ),
          ),
        ),
      );
    }

    // Collage: up to 4 images in a 2x2 grid
    final cols = images.length == 1 ? 1 : 2;
    final rows = (images.length / cols).ceil();
    final collageHeight = (rows * 80.0).clamp(80.0, 200.0);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: collageHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: images.length.clamp(1, 4),
          itemBuilder: (_, i) => Image.file(
            File(images[i]),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colors.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, color: colors.outline),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Layout Picker Bottom Sheet
// ─────────────────────────────────────────────
class _LayoutPickerSheet extends StatelessWidget {
  final _PageLayout current;
  final List<String> images;
  final void Function(_PageLayout) onSelect;
  final VoidCallback onAddImage;

  const _LayoutPickerSheet({
    required this.current,
    required this.images,
    required this.onSelect,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('PAGE LAYOUT',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: colors.primary)),
            const SizedBox(height: 16),
            Row(
              children: [
                _LayoutOption(
                  icon: Icons.view_agenda_outlined,
                  label: 'Text only',
                  selected: current == _PageLayout.textOnly,
                  onTap: () => onSelect(_PageLayout.textOnly),
                  colors: colors,
                ),
                const SizedBox(width: 12),
                _LayoutOption(
                  icon: Icons.image_outlined,
                  label: 'Image header',
                  selected: current == _PageLayout.imageSide,
                  onTap: () => onSelect(_PageLayout.imageSide),
                  colors: colors,
                ),
                const SizedBox(width: 12),
                _LayoutOption(
                  icon: Icons.grid_view_rounded,
                  label: 'Collage',
                  selected: current == _PageLayout.collage,
                  onTap: () => onSelect(_PageLayout.collage),
                  colors: colors,
                ),
              ],
            ),
            if (current != _PageLayout.textOnly) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: Text(
                  current == _PageLayout.collage
                      ? 'Replace images (up to 4)'
                      : 'Replace image',
                ),
                onTap: onAddImage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _LayoutOption({
    required this.icon, required this.label, required this.selected,
    required this.onTap, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? colors.primary : colors.outline,
                  size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? colors.primary : colors.outline,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Word Count Bar
// ─────────────────────────────────────────────
class _WordCountBar extends StatelessWidget {
  final int wordCount;
  final bool isSaving;

  const _WordCountBar({required this.wordCount, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final readingTime = TextUtils.formatReadingTime(TextUtils.readingTimeSec(wordCount));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Text('$wordCount ${wordCount == 1 ? 'word' : 'words'}',
              style: TextStyle(fontSize: 12, color: colors.outline)),
          const SizedBox(width: 16),
          Text(readingTime,
              style: TextStyle(fontSize: 12, color: colors.outline)),
          const Spacer(),
          if (isSaving)
            Text('Saving…', style: TextStyle(fontSize: 12, color: colors.primary))
          else
            Text('Auto-saved', style: TextStyle(fontSize: 12, color: colors.outline)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Entry Background Picker Bottom Sheet
// ─────────────────────────────────────────────
class _EntryBgPickerSheet extends StatelessWidget {
  final String? currentPresetId;
  final String? currentImagePath;
  final void Function(String presetId) onPreset;
  final void Function(String path) onImage;
  final VoidCallback onClear;

  const _EntryBgPickerSheet({
    required this.currentPresetId,
    required this.currentImagePath,
    required this.onPreset,
    required this.onImage,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasOverride = currentPresetId != null || currentImagePath != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'ENTRY BACKGROUND',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colors.primary,
                  ),
                ),
                const Spacer(),
                if (hasOverride)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Clear override'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Overrides the global background for this entry only.',
              style: TextStyle(fontSize: 12, color: colors.outline),
            ),
            const SizedBox(height: 16),

            // ── Preset grid ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kBackgroundPresets.map((preset) {
                final isSelected = preset.id == currentPresetId;
                return GestureDetector(
                  onTap: () => onPreset(preset.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? colors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildPresetSwatch(preset),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Pick from photos ──
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: currentImagePath != null
                      ? Border.all(color: colors.primary, width: 2)
                      : null,
                ),
                child: currentImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(currentImagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.broken_image_outlined, color: colors.outline, size: 20),
                        ),
                      )
                    : Icon(Icons.add_photo_alternate_outlined, color: colors.outline),
              ),
              title: Text(currentImagePath != null ? 'Change photo' : 'Pick from photos'),
              subtitle: currentImagePath != null
                  ? const Text('Custom image active', style: TextStyle(fontSize: 11))
                  : null,
              onTap: () async {
                final picker = ImagePicker();
                final file = await picker.pickImage(source: ImageSource.gallery);
                if (file != null) onImage(file.path);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSwatch(BackgroundPreset preset) {
    final bg = preset.background;
    if (bg.type == AppBackgroundType.gradient && bg.gradientColors != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bg.gradientColors!,
          ),
        ),
      );
    }
    return Container(color: bg.color ?? const Color(0xFFF9F7F4));
  }
}

// Paints the optional page texture behind the editor content.
// Uses the same PageStyle enum as the book reading view.
class _EditorTexturePainter extends CustomPainter {
  final PageStyle style;
  final Color lineColor;
  const _EditorTexturePainter({required this.style, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PageStyle.blank) return;
    final paint = Paint()..color = lineColor.withAlpha(60)..strokeWidth = 0.7;
    switch (style) {
      case PageStyle.ruled:
        for (double y = 32; y < size.height; y += 30) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case PageStyle.dotted:
        for (double y = 32; y < size.height; y += 26) {
          for (double x = 16; x < size.width; x += 26) {
            canvas.drawCircle(Offset(x, y), 1.1, paint..style = PaintingStyle.fill);
          }
        }
      case PageStyle.grid:
        for (double y = 32; y < size.height; y += 26) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (double x = 26; x < size.width; x += 26) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
      case PageStyle.blank:
        break;
    }
  }

  @override
  bool shouldRepaint(_EditorTexturePainter old) =>
      old.style != style || old.lineColor != lineColor;
}
