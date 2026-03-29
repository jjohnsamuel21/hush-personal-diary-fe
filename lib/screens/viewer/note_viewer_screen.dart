import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/constants/font_constants.dart';
import '../../core/utils/text_utils.dart';
import '../../models/note.dart';
import '../../services/note_service.dart';
import '../../widgets/common/app_background.dart';

/// Read-only view of a note — opened when the user taps a note card.
/// Shows decrypted content in a clean, distraction-free layout.
/// The "Edit" button in the AppBar opens NoteEditorScreen.
class NoteViewerScreen extends ConsumerStatefulWidget {
  final int noteId;
  final int folderId;

  const NoteViewerScreen({
    super.key,
    required this.noteId,
    required this.folderId,
  });

  @override
  ConsumerState<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends ConsumerState<NoteViewerScreen> {
  QuillController? _controller;
  late ScrollController _scrollController;
  late FocusNode _focusNode;
  Note? _note;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final note = await NoteService.getNoteById(widget.noteId);
    if (!mounted) return;

    if (note == null) {
      setState(() => _ready = true);
      return;
    }

    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) {
      setState(() { _note = note; _ready = true; });
      return;
    }

    final deltaJson = NoteService.decryptBody(note, masterKey);
    final doc = Document.fromJson(jsonDecode(deltaJson) as List);
    final ctrl = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    if (!mounted) { ctrl.dispose(); return; }
    setState(() { _controller = ctrl; _note = note; _ready = true; });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _note == null
            ? const SizedBox.shrink()
            : Text(
                _note!.title
                    .replaceAll('\n', ' ')
                    .replaceAll('\r', '')
                    .trim(),
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_note != null)
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
              onPressed: () => context.push(
                '/editor?noteId=${widget.noteId}&folderId=${widget.folderId}',
              ),
            ),
        ],
      ),
      body: AppBackgroundWrapper(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : _note == null
                ? Center(
                    child: Text('Entry not found',
                        style: TextStyle(color: colors.outline)),
                  )
                : _buildContent(context, colors),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colors) {
    final note = _note!;
    final font = noteFontFromString(note.fontFamily);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Meta strip ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Text(_formatDate(note.createdAt),
                  style: TextStyle(fontSize: 12, color: colors.outline)),
              const SizedBox(width: 12),
              Text('${note.wordCount} words',
                  style: TextStyle(fontSize: 12, color: colors.outline)),
              const SizedBox(width: 12),
              Text(TextUtils.formatReadingTime(note.readingTimeSec),
                  style: TextStyle(fontSize: 12, color: colors.outline)),
            ],
          ),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),

        // ── Entry body — QuillEditor with scrollable: true (default) ──────
        // Must be inside an Expanded so it has a bounded height.
        // scrollable: false + unbounded height = RenderErrorBox crash.
        Expanded(
          child: _controller == null
              ? Center(
                  child: Text('Could not decrypt entry.',
                      style: TextStyle(color: colors.error)),
                )
              : DefaultTextStyle.merge(
                  style: noteFontStyle(font, fontSize: 17),
                  child: QuillEditor(
                    controller: _controller!,
                    scrollController: _scrollController,
                    focusNode: _focusNode,
                    config: const QuillEditorConfig(
                      showCursor: false,
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
                      autoFocus: false,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
