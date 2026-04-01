import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/constants/font_constants.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/utils/text_utils.dart';
import '../../models/note.dart';
import '../../providers/background_provider.dart';
import '../../providers/page_style_provider.dart';
import '../../providers/typography_provider.dart';
import '../../services/note_service.dart';

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
      body: _NoteBackgroundWrapper(
        note: _note,
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
    final typo = ref.watch(typographyProvider);

    // Apply global typography settings so changes in Settings instantly
    // reflect across ALL existing entries.
    final font = noteFontFromString(
      typo.fontFamily != 'Merriweather' ? typo.fontFamily : note.fontFamily,
    );
    final bodyColor = typo.useCustomColor ? typo.textColor : null;
    final bodySize = 17.0 * typo.fontScale;
    final hasImages = note.layoutImages.isNotEmpty && note.pageLayout != 'text_only';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Image header / collage ────────────────────────────────────────
        if (hasImages) _ViewerImageStrip(note: note, colors: colors),

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
          child: Stack(
            children: [
              CustomPaint(
                painter: _ViewerTexturePainter(
                  style: ref.watch(pageStyleProvider),
                  lineColor: Theme.of(context).colorScheme.outlineVariant,
                ),
                child: const SizedBox.expand(),
              ),
              _controller == null
                  ? Center(
                      child: Text('Could not decrypt entry.',
                          style: TextStyle(color: colors.error)),
                    )
                  : DefaultTextStyle.merge(
                      style: noteFontStyle(font, fontSize: bodySize).copyWith(
                        color: bodyColor,
                        height: 1.65,
                      ),
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
            ],
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

// Applies note-specific background if set, otherwise falls back to global background.
// Priority: note custom image → note preset → global AppBackground.
class _NoteBackgroundWrapper extends ConsumerWidget {
  final Note? note;
  final Widget child;
  const _NoteBackgroundWrapper({required this.note, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalBg = ref.watch(backgroundProvider);
    final effective = note == null
        ? globalBg
        : resolveNoteBackground(
            noteBgPresetId: note!.noteBgPresetId,
            noteBgImagePath: note!.noteBgImagePath,
            journalOrGlobalBackground: globalBg,
          );

    switch (effective.type) {
      case AppBackgroundType.image:
        if (effective.imagePath != null && File(effective.imagePath!).existsSync()) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(effective.imagePath!), fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.15)),
              child,
            ],
          );
        }
        return child;
      case AppBackgroundType.gradient:
        final colors = effective.gradientColors ?? [const Color(0xFFF9F7F4), const Color(0xFFEEEEEE)];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: child,
        );
      case AppBackgroundType.color:
        return Container(color: effective.color ?? const Color(0xFFF9F7F4), child: child);
    }
  }
}

// Shows saved image header or collage in read-only view.
class _ViewerImageStrip extends StatelessWidget {
  final Note note;
  final ColorScheme colors;
  const _ViewerImageStrip({required this.note, required this.colors});

  @override
  Widget build(BuildContext context) {
    final images = note.layoutImages;
    final isCollage = note.pageLayout == 'collage';
    final height = isCollage ? (images.length > 2 ? 160.0 : 120.0) : 200.0;

    if (!isCollage) {
      // Single image header
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Image.file(
          File(images.first),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: height,
            color: colors.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined, color: colors.outline),
          ),
        ),
      );
    }

    // Collage: up to 4 images
    final cols = images.length == 1 ? 1 : 2;
    final rows = (images.length / cols).ceil();
    final collageHeight = rows * 80.0;
    return SizedBox(
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
    );
  }
}

class _ViewerTexturePainter extends CustomPainter {
  final PageStyle style;
  final Color lineColor;
  const _ViewerTexturePainter({required this.style, required this.lineColor});

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
  bool shouldRepaint(_ViewerTexturePainter old) =>
      old.style != style || old.lineColor != lineColor;
}
