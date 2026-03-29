import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/folder.dart';

/// The first page of a journal in book view.
/// Shows the journal's cover image (if set), name, and entry count.
class BookCoverPage extends StatelessWidget {
  final Folder folder;
  final int entryCount;
  final HushTheme theme;

  const BookCoverPage({
    super.key,
    required this.folder,
    required this.entryCount,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = folder.coverImagePath != null &&
        File(folder.coverImagePath!).existsSync();
    final folderColor = _hexColor(folder.color);

    return Container(
      color: hasCover ? Colors.black : theme.pageBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image or decorative background
          if (hasCover)
            Image.file(
              File(folder.coverImagePath!),
              fit: BoxFit.cover,
            )
          else
            CustomPaint(
              painter: _PageTexturePainter(
                style: theme.pageStyle,
                lineColor: theme.pageLines,
              ),
            ),

          // Dark gradient overlay (always on image, subtle on plain)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasCover
                    ? [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.65),
                      ]
                    : [
                        Colors.transparent,
                        folderColor.withValues(alpha: 0.08),
                      ],
              ),
            ),
          ),

          // Cover content: title block at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Journal icon circle at top
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: hasCover
                        ? Colors.white.withValues(alpha: 0.2)
                        : folderColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: hasCover ? Colors.white : folderColor,
                    size: 28,
                  ),
                ),
                const Spacer(),
                // Journal name
                Text(
                  folder.name,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: hasCover ? Colors.white : theme.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Entry count
                Text(
                  '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasCover
                        ? Colors.white70
                        : theme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 16),
                // Decorative rule
                Container(
                  width: 48,
                  height: 2,
                  decoration: BoxDecoration(
                    color: hasCover
                        ? Colors.white.withValues(alpha: 0.5)
                        : folderColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF5C6BC0);
    }
  }
}

class _PageTexturePainter extends CustomPainter {
  final PageStyle style;
  final Color lineColor;
  const _PageTexturePainter({required this.style, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PageStyle.blank) return;
    final paint = Paint()..color = lineColor..strokeWidth = 0.8;
    switch (style) {
      case PageStyle.ruled:
        for (double y = 72; y < size.height; y += 28) {
          canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
        }
      case PageStyle.dotted:
        for (double y = 48; y < size.height; y += 24) {
          for (double x = 24; x < size.width; x += 24) {
            canvas.drawCircle(Offset(x, y), 1.2, paint..style = PaintingStyle.fill);
          }
        }
      case PageStyle.grid:
        for (double y = 48; y < size.height; y += 24) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
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
