import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/font_constants.dart';
import '../../core/constants/theme_constants.dart';
import '../../models/note.dart';
import '../../providers/background_provider.dart';
import '../../providers/page_style_provider.dart';
import '../../providers/typography_provider.dart';
import '../../screens/editor/image_embed_builder.dart';

// A single entry page in book view — the Kindle-style content page.
//
// Design principles:
//   • Generous side margins (24px) — mirrors Kindle's comfortable reading margins
//   • Entry title + date as chapter header at top of the scrollable content
//   • QuillEditor in read-only mode fills the rest — no separate chapter-header page
//   • Scroll position feeds back to BookScreen for the progress bar
//   • Page texture (ruled/dots/grid) painted behind the text
class BookContentPage extends ConsumerStatefulWidget {
  final Note note;
  final Document doc;
  final HushTheme theme;
  final int entryNumber;
  final int totalEntries;
  final void Function(double fraction) onScrollFraction;

  const BookContentPage({
    super.key,
    required this.note,
    required this.doc,
    required this.theme,
    required this.entryNumber,
    required this.totalEntries,
    required this.onScrollFraction,
  });

  @override
  ConsumerState<BookContentPage> createState() => _BookContentPageState();
}

class _BookContentPageState extends ConsumerState<BookContentPage> {
  late QuillController _controller;
  late ScrollController _scrollController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _controller = QuillController(
      document: widget.doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final sc = _scrollController;
    if (!sc.hasClients) return;
    final max = sc.position.maxScrollExtent;
    if (max <= 0) return;
    widget.onScrollFraction(
        (sc.offset / max).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageStyle = ref.watch(pageStyleProvider);
    final typo = ref.watch(typographyProvider);

    // Global typography overrides the per-note font if set.
    // This ensures changes in Settings › Appearance instantly apply to ALL entries.
    final bodyFont = typo.fontFamily != 'Merriweather'
        ? typo.fontFamily
        : widget.note.fontFamily;
    final bodyColor = typo.useCustomColor
        ? typo.textColor
        : widget.theme.textPrimary;
    final bodySize = 17.0 * typo.fontScale;

    // If the note has an entry-specific background, overlay it on top of the
    // journal/global background that the parent JournalBackgroundWrapper provides.
    final globalBg = ref.watch(backgroundProvider);
    final noteBg = resolveNoteBackground(
      noteBgPresetId: widget.note.noteBgPresetId,
      noteBgImagePath: widget.note.noteBgImagePath,
      journalOrGlobalBackground: globalBg,
    );
    final hasNoteOverride =
        widget.note.noteBgPresetId != null || widget.note.noteBgImagePath != null;

    Widget bgLayer = const SizedBox.shrink();
    if (hasNoteOverride) {
      switch (noteBg.type) {
        case AppBackgroundType.image:
          if (noteBg.imagePath != null && File(noteBg.imagePath!).existsSync()) {
            bgLayer = Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(noteBg.imagePath!), fit: BoxFit.cover),
                Container(color: Colors.black.withValues(alpha: 0.15)),
              ],
            );
          }
        case AppBackgroundType.gradient:
          final gColors = noteBg.gradientColors ?? [const Color(0xFFF9F7F4), const Color(0xFFEEEEEE)];
          bgLayer = Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gColors,
              ),
            ),
          );
        case AppBackgroundType.color:
          bgLayer = Container(color: noteBg.color ?? const Color(0xFFF9F7F4));
      }
    }

    return Stack(
      children: [
        if (hasNoteOverride) Positioned.fill(child: bgLayer),
        _buildPage(context, pageStyle, bodyFont, bodyColor, bodySize),
      ],
    );
  }

  Widget _buildPage(BuildContext context, PageStyle pageStyle,
      String bodyFont, Color bodyColor, double bodySize) {
    return Stack(
      children: [
          // ── Page texture layer ──────────────────────────────────────────────
          CustomPaint(
            painter: _PageTexturePainter(
              style: pageStyle,
              lineColor: widget.theme.pageLines,
            ),
            child: const SizedBox.expand(),
          ),

          // ── Scrollable content ──────────────────────────────────────────────
          // All content flows in one scroll — no separate chapter page needed.
          // The chapter "title block" sits at the top of the same scroll container.
          CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              // ── Top safe area spacing (for the auto-hiding toolbar) ──────
              SliverToBoxAdapter(
                child: SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 8),
              ),

              // ── Chapter header ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Entry label (e.g. "Entry 3 of 12")
                      Text(
                        'ENTRY ${widget.entryNumber} OF ${widget.totalEntries}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: widget.theme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Entry title
                      Text(
                        widget.note.title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: widget.theme.textPrimary,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Date + word count + reading time
                      Row(
                        children: [
                          Text(
                            _formatDate(widget.note.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.theme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _dot(widget.theme.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.note.wordCount} words',
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.theme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _dot(widget.theme.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            _readingTime(widget.note.readingTimeSec),
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Decorative rule — the "chapter line" before body text
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: widget.theme.pageLines,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.theme.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: widget.theme.pageLines,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Quill body ────────────────────────────────────────────────
              // NeverScrollableScrollPhysics — the outer CustomScrollView handles all scrolling.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DefaultTextStyle.merge(
                    style: noteFontStyle(
                      noteFontFromString(bodyFont),
                      fontSize: bodySize,
                    ).copyWith(
                      height: 1.65,
                      color: bodyColor,
                      letterSpacing: 0.1,
                    ),
                    child: QuillEditor(
                      controller: _controller,
                      scrollController: ScrollController(),
                      focusNode: _focusNode,
                      config: QuillEditorConfig(
                        showCursor: false,
                        scrollable: false,        // outer scroll handles it
                        padding: EdgeInsets.zero,
                        autoFocus: false,
                        embedBuilders: [LocalImageEmbedBuilder()],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom padding (clear of the progress bar) ──────────────
              const SliverToBoxAdapter(
                child: SizedBox(height: 72),
              ),
            ],
          ),
        ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _readingTime(int seconds) {
    if (seconds < 60) return '< 1 min read';
    final mins = (seconds / 60).ceil();
    return '~$mins min read';
  }
}

// Draws the page texture behind the content (unchanged from original).
class _PageTexturePainter extends CustomPainter {
  final PageStyle style;
  final Color lineColor;
  const _PageTexturePainter({required this.style, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (style == PageStyle.blank) return;
    final paint = Paint()..color = lineColor..strokeWidth = 0.7;
    switch (style) {
      case PageStyle.ruled:
        for (double y = 80; y < size.height; y += 30) {
          canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
        }
      case PageStyle.dotted:
        for (double y = 56; y < size.height; y += 26) {
          for (double x = 26; x < size.width; x += 26) {
            canvas.drawCircle(
                Offset(x, y), 1.0, paint..style = PaintingStyle.fill);
          }
        }
      case PageStyle.grid:
        for (double y = 56; y < size.height; y += 26) {
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
  bool shouldRepaint(_PageTexturePainter old) =>
      old.style != style || old.lineColor != lineColor;
}
