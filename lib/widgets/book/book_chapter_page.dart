import 'package:flutter/material.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/note.dart';

/// A chapter-header page shown before each entry's content in book view.
/// Displays the entry title, date, and word count — full page, centered.
class BookChapterPage extends StatelessWidget {
  final Note note;
  final int chapterNumber;
  final HushTheme theme;

  const BookChapterPage({
    super.key,
    required this.note,
    required this.chapterNumber,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.pageBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Page texture
          CustomPaint(
            painter: _ChapterTexturePainter(lineColor: theme.pageLines),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                // Chapter label
                Text(
                  'Entry $chapterNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Entry title
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 24),
                // Date + word count row
                Row(
                  children: [
                    Text(
                      _formatDate(note.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${note.wordCount} words',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Decorative divider
                Container(
                  width: 48,
                  height: 2,
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const Spacer(flex: 2),
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

class _ChapterTexturePainter extends CustomPainter {
  final Color lineColor;
  const _ChapterTexturePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Single bottom rule on the bottom third
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(40, size.height * 0.62),
      Offset(size.width - 40, size.height * 0.62),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChapterTexturePainter old) => old.lineColor != lineColor;
}
