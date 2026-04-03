import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/font_constants.dart';
import '../../services/activity_log_service.dart';
import '../../core/utils/text_utils.dart';
import '../../models/shared_note.dart';
import '../../providers/page_style_provider.dart';
import '../../providers/shared_notes_provider.dart';
import '../../services/collab_service.dart';
import '../../widgets/common/app_background.dart';
import '../../core/constants/theme_constants.dart';
import '../editor/audio_embed_builder.dart';

/// Editor for a shared note — visually identical to NoteEditorScreen but
/// saves via SharedNoteService (backend + local cache) instead of encrypting
/// locally.  Body is stored as Quill Delta JSON so rich formatting is
/// preserved across collaborators.
///
/// Live collaboration: when the note has a server-assigned ID a WebSocket
/// connection is opened so all editors see each other's changes in real time.
class SharedNoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  const SharedNoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<SharedNoteEditorScreen> createState() =>
      _SharedNoteEditorScreenState();
}

class _SharedNoteEditorScreenState
    extends ConsumerState<SharedNoteEditorScreen> {
  QuillController? _controller;
  late ScrollController _scrollController;
  late FocusNode _focusNode;
  late TextEditingController _titleCtrl;

  SharedNote? _note;
  bool _editorReady = false;
  bool _isSaving = false;
  bool _advancedToolbar = false;
  int _wordCount = 0;
  NoteFont _currentFont = NoteFont.merriweather;

  Timer? _debounceTimer;

  // ── Collab state ──────────────────────────────────────────────────────────
  CollabService? _collab;
  StreamSubscription<dynamic>? _docChangeSub;
  bool _applyingRemote = false;          // blocks re-broadcast of incoming ops
  List<CollabUser> _onlineUsers = [];    // collaborators currently in the room
  Map<String, RemoteCursor> _cursors = {}; // user_id → last known cursor

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _titleCtrl = TextEditingController();
    _initEditor();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _docChangeSub?.cancel();
    _controller?.removeListener(_onDocumentChanged);
    _controller?.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _titleCtrl.dispose();
    _collab?.disconnect();
    super.dispose();
  }

  Future<void> _initEditor() async {
    QuillController controller;

    if (widget.noteId != null) {
      final cached = ref.read(sharedNotesProvider).valueOrNull;
      final note = cached?.where((n) => n.id == widget.noteId).firstOrNull;

      if (note != null) {
        _titleCtrl.text = note.title;
        _currentFont = noteFontFromString(note.fontFamily);
        controller = _controllerFromBody(note.body, readOnly: !note.canEdit);
        if (!mounted) { controller.dispose(); return; }
        setState(() => _note = note);
      } else {
        controller = QuillController.basic();
      }
    } else {
      controller = QuillController.basic();
    }

    controller.addListener(_onDocumentChanged);

    // Subscribe to document delta stream to send live ops over WebSocket.
    _docChangeSub = controller.document.changes.listen((event) {
      if (_applyingRemote || event.source == ChangeSource.remote) return;
      _collab?.sendDelta(event.change.toJson());
    });

    if (!mounted) { controller.dispose(); return; }
    setState(() {
      _controller = controller;
      _editorReady = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    // Connect collab WebSocket for server-synced notes (not local_ drafts).
    final id = widget.noteId;
    if (id != null && !id.startsWith('local_')) {
      _connectCollab(id);
    }
  }

  void _connectCollab(String noteId) {
    _collab = CollabService(noteId: noteId)
      ..onRemoteDelta = _applyRemoteDelta
      ..onPresenceChanged = (users) {
        if (mounted) setState(() => _onlineUsers = users);
      }
      ..onCursorChanged = (cursor) {
        if (mounted) {
          setState(() => _cursors[cursor.userId] = cursor);
        }
      };
    _collab!.connect();
  }

  /// Applies a remote delta to the document without triggering our own
  /// change listener or HTTP auto-save.
  void _applyRemoteDelta(List<dynamic> ops) {
    final ctrl = _controller;
    if (ctrl == null || !mounted) return;
    try {
      final delta = Delta.fromJson(ops);
      _applyingRemote = true;
      ctrl.document.compose(delta, ChangeSource.remote);
    } catch (_) {
      // Ignore malformed deltas — document stays as-is.
    } finally {
      _applyingRemote = false;
    }
  }

  /// Builds a QuillController from a body string that may be Delta JSON
  /// (starts with '[') or legacy plain text.
  QuillController _controllerFromBody(String body, {bool readOnly = false}) {
    Document doc;
    if (body.isNotEmpty && body.trimLeft().startsWith('[')) {
      try {
        doc = Document.fromJson(jsonDecode(body) as List);
      } catch (_) {
        doc = Document.fromJson([if (body.isNotEmpty) {'insert': '$body\n'}]);
      }
    } else if (body.isNotEmpty) {
      doc = Document.fromJson([{'insert': '$body\n'}]);
    } else {
      return readOnly
          ? QuillController(
              document: Document(),
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: true,
            )
          : QuillController.basic();
    }
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: readOnly,
    );
  }

  void _onDocumentChanged() {
    if (_applyingRemote) return;

    final ctrl = _controller;
    if (ctrl == null) return;

    // Update word count.
    final count = TextUtils.countWords(ctrl.document.toPlainText());
    if (count != _wordCount) setState(() => _wordCount = count);

    // Broadcast cursor position.
    final sel = ctrl.selection;
    if (sel.isValid) {
      _collab?.sendCursor(sel.baseOffset, sel.extentOffset - sel.baseOffset);
    }

    // Debounced HTTP auto-save.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), _autoSave);
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

    final deltaJson = jsonEncode(ctrl.document.toDelta().toJson());
    final title = _titleCtrl.text.trim().isEmpty ? 'Untitled' : _titleCtrl.text.trim();

    if (_note == null) {
      final created = await ref
          .read(sharedNotesNotifierProvider.notifier)
          .createNote(
            title: title,
            body: deltaJson,
            fontFamily: _currentFont.label,
          );
      ActivityLogService.log(
        sessionType: 'shared',
        noteId: created.id,
        action: 'created',
        noteTitle: created.title,
      );
      if (mounted) {
        setState(() => _note = created);
        if (widget.noteId == null) {
          context.replace('/shared/editor?noteId=${created.id}');
          // Connect collab now that we have a real server ID.
          if (!created.id.startsWith('local_')) {
            _connectCollab(created.id);
          }
        }
      }
    } else {
      final canEdit = _note!.canEdit;
      if (!canEdit) return;
      await ref.read(sharedNotesNotifierProvider.notifier).updateNote(
            _note!.id,
            title: title,
            body: deltaJson,
            fontFamily: _currentFont.label,
          );
      ActivityLogService.log(
        sessionType: 'shared',
        noteId: _note!.id,
        action: 'edited',
        noteTitle: title,
      );
    }
  }

  Future<void> _onDone() async {
    _debounceTimer?.cancel();
    await _save();
    if (mounted) context.pop();
  }

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

  void _openFontPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SharedFontPickerSheet(
        current: _currentFont,
        onSelect: (font) {
          Navigator.pop(context);
          setState(() => _currentFont = font);
          _autoSave();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final readOnly = _note != null && !_note!.canEdit;
    final isLocal = _note?.id.startsWith('local_') == true;

    // Other editors minus self (presence list includes self).
    final others = _onlineUsers.where((u) => u.id != _note?.ownerEmail).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onDone,
        ),
        title: readOnly
            ? Text(_note?.title ?? 'Shared note',
                style: const TextStyle(fontWeight: FontWeight.w600))
            : TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Note title…',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _autoSave(),
              ),
        actions: [
          // Live presence dots — coloured circles for each online collaborator.
          if (_onlineUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _onlineUsers.take(5).map((u) {
                  return Tooltip(
                    message: u.name,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: u.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (!readOnly) ...[
            IconButton(
              icon: Icon(Icons.mic_rounded, color: colors.primary),
              tooltip: 'Voice note',
              onPressed: _openAudioRecorder,
            ),
            IconButton(
              icon: Icon(Icons.text_fields_rounded, color: colors.primary),
              tooltip: 'Font',
              onPressed: _openFontPicker,
            ),
            PopupMenuButton<_SharedEditorAction>(
              icon: Icon(Icons.add_circle_outline, color: colors.primary),
              tooltip: 'More',
              onSelected: (action) {
                switch (action) {
                  case _SharedEditorAction.toggleToolbar:
                    setState(() => _advancedToolbar = !_advancedToolbar);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _SharedEditorAction.toggleToolbar,
                  child: ListTile(
                    leading: Icon(_advancedToolbar
                        ? Icons.expand_less
                        : Icons.expand_more),
                    title: Text(_advancedToolbar
                        ? 'Basic toolbar'
                        : 'Advanced toolbar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
          if (_note != null && _note!.isOwner)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Collaborators',
              onPressed: () =>
                  context.push('/shared/manage?noteId=${_note!.id}'),
            ),
        ],
      ),
      body: AppBackgroundWrapper(
        child: !_editorReady
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Collaborator banner (non-owner) ──────────────────────
                  if (_note != null && !_note!.isOwner)
                    MaterialBanner(
                      content: Text(
                        readOnly
                            ? 'You have read-only access.'
                            : 'Shared by ${_note!.ownerDisplayName ?? _note!.ownerEmail}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      leading: Icon(
                        readOnly
                            ? Icons.visibility_outlined
                            : Icons.people_outline,
                        size: 20,
                      ),
                      backgroundColor: colors.secondaryContainer,
                      actions: [
                        TextButton(onPressed: () {}, child: const Text('OK'))
                      ],
                    ),

                  // ── Offline badge ────────────────────────────────────────
                  if (isLocal)
                    Container(
                      width: double.infinity,
                      color: colors.tertiaryContainer.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off_outlined,
                              size: 14,
                              color: colors.onTertiaryContainer),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Not synced — sign in with Google and tap Sync',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onTertiaryContainer),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _isSaving ? null : () async {
                              setState(() => _isSaving = true);
                              await _save();
                              if (mounted) setState(() => _isSaving = false);
                            },
                            child: Text('Sync',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onTertiaryContainer,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // ── Active editors bar (live collab) ─────────────────────
                  if (_onlineUsers.length > 1)
                    _CollabBar(users: _onlineUsers),

                  // ── Quill toolbar ────────────────────────────────────────
                  if (!readOnly)
                    QuillSimpleToolbar(
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
                  if (!readOnly) const Divider(height: 1),

                  // ── Editor body ──────────────────────────────────────────
                  Expanded(
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: _SharedEditorTexturePainter(
                            style: ref.watch(pageStyleProvider),
                            lineColor:
                                Theme.of(context).colorScheme.outlineVariant,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: DefaultTextStyle.merge(
                            style:
                                noteFontStyle(_currentFont, fontSize: 16),
                            child: QuillEditor(
                              controller: _controller!,
                              scrollController: _scrollController,
                              focusNode: _focusNode,
                              config: QuillEditorConfig(
                                placeholder: readOnly
                                    ? null
                                    : 'Write something together…',
                                padding: const EdgeInsets.only(top: 8),
                                showCursor: !readOnly,
                                embedBuilders: const [AudioEmbedBuilder()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Word / status bar ────────────────────────────────────
                  _SharedWordCountBar(
                      wordCount: _wordCount,
                      isSaving: _isSaving,
                      isLocal: isLocal),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active editors bar — shown when ≥2 people are in the room
// ─────────────────────────────────────────────────────────────────────────────
class _CollabBar extends StatelessWidget {
  final List<CollabUser> users;
  const _CollabBar({required this.users});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record,
              size: 8, color: Colors.greenAccent.shade400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${users.length} editing now — ${users.map((u) => u.name.split(' ').first).join(', ')}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum for overflow menu actions
// ─────────────────────────────────────────────────────────────────────────────
enum _SharedEditorAction { toggleToolbar }

// ─────────────────────────────────────────────────────────────────────────────
// Font picker sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SharedFontPickerSheet extends StatelessWidget {
  final NoteFont current;
  final void Function(NoteFont) onSelect;
  const _SharedFontPickerSheet({required this.current, required this.onSelect});

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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('NOTE FONT',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colors.primary)),
            const SizedBox(height: 12),
            ...NoteFont.values.map((font) {
              final isSelected = font == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: isSelected
                    ? Icon(Icons.check_circle_rounded, color: colors.primary)
                    : Icon(Icons.circle_outlined, color: colors.outlineVariant),
                title: Text(font.label, style: noteFontStyle(font, fontSize: 16)),
                subtitle: Text(font.description,
                    style: TextStyle(fontSize: 12, color: colors.outline)),
                onTap: () => onSelect(font),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Word / status bar
// ─────────────────────────────────────────────────────────────────────────────
class _SharedWordCountBar extends StatelessWidget {
  final int wordCount;
  final bool isSaving;
  final bool isLocal;
  const _SharedWordCountBar(
      {required this.wordCount,
      required this.isSaving,
      required this.isLocal});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final readingTime =
        TextUtils.formatReadingTime(TextUtils.readingTimeSec(wordCount));

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
            Text('Saving…',
                style: TextStyle(fontSize: 12, color: colors.primary))
          else if (isLocal)
            Text('Offline',
                style: TextStyle(fontSize: 12, color: colors.error))
          else
            Text('Auto-saved',
                style: TextStyle(fontSize: 12, color: colors.outline)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page texture painter
// ─────────────────────────────────────────────────────────────────────────────
class _SharedEditorTexturePainter extends CustomPainter {
  final PageStyle style;
  final Color lineColor;
  const _SharedEditorTexturePainter(
      {required this.style, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PageStyle.blank) return;
    final paint = Paint()
      ..color = lineColor.withAlpha(60)
      ..strokeWidth = 0.7;
    switch (style) {
      case PageStyle.ruled:
        for (double y = 32; y < size.height; y += 30) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case PageStyle.dotted:
        for (double y = 32; y < size.height; y += 26) {
          for (double x = 16; x < size.width; x += 26) {
            canvas.drawCircle(
                Offset(x, y), 1.1, paint..style = PaintingStyle.fill);
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
  bool shouldRepaint(_SharedEditorTexturePainter old) =>
      old.style != style || old.lineColor != lineColor;
}
