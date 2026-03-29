import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/note.dart';
import '../../screens/editor/image_embed_builder.dart';

// A single "page" rendered inside the BookScreen's PageFlipWidget.
// Receives an already-decrypted Quill [Document] so the page doesn't
// re-decrypt on every render frame.
//
// Renders a read-only Quill editor on a styled background that matches
// the active HushTheme's page style (blank, ruled, dotted, grid).
class BookPage extends StatefulWidget {
  final Note note;
  final Document doc;
  final HushTheme theme;

  const BookPage({
    super.key,
    required this.note,
    required this.doc,
    required this.theme,
  });

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  late QuillController _controller;
  late ScrollController _scrollController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    // Build one controller per page — read-only, no auto-save needed
    _controller = QuillController(
      document: widget.doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.theme.pageBackground,
      child: Stack(
        children: [
          // Page texture layer (ruled lines / dots / grid)
          CustomPaint(
            painter: _PageTexturePainter(
              style: widget.theme.pageStyle,
              lineColor: widget.theme.pageLines,
            ),
            child: const SizedBox.expand(),
          ),

          // Note content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note title
                Text(
                  widget.note.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.theme.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(widget.note.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const Divider(height: 24),

                // Quill read-only editor
                Expanded(
                  child: QuillEditor(
                    controller: _controller,
                    scrollController: _scrollController,
                    focusNode: _focusNode,
                    config: QuillEditorConfig(
                      showCursor: false,
                      padding: EdgeInsets.zero,
                      embedBuilders: [LocalImageEmbedBuilder()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

// Draws the page texture behind the note text.
class _PageTexturePainter extends CustomPainter {
  final PageStyle style;
  final Color lineColor;

  const _PageTexturePainter({required this.style, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PageStyle.blank) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    switch (style) {
      case PageStyle.ruled:
        // Horizontal ruled lines every 28px, starting from y=72
        for (double y = 72; y < size.height; y += 28) {
          canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
        }
      case PageStyle.dotted:
        // Dot grid every 24px
        for (double y = 48; y < size.height; y += 24) {
          for (double x = 24; x < size.width; x += 24) {
            canvas.drawCircle(Offset(x, y), 1.2, paint..style = PaintingStyle.fill);
          }
        }
      case PageStyle.grid:
        // Horizontal lines
        for (double y = 48; y < size.height; y += 24) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        // Vertical lines
        for (double x = 24; x < size.width; x += 24) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
      case PageStyle.blank:
        break;
    }
  }

  @override
  bool shouldRepaint(_PageTexturePainter old) =>
      old.style != style || old.lineColor != lineColor;
}
