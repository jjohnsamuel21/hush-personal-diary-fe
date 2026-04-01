import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../models/folder.dart';
import '../../models/note.dart';
import '../../providers/background_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/folder_service.dart';
import '../../services/note_service.dart';
import '../../widgets/book/book_content_page.dart';
import '../../widgets/book/book_cover_page.dart';
import '../../widgets/common/journal_background.dart';

// ── BookScreen ────────────────────────────────────────────────────────────────
// Kindle-style reading view for a journal.
//
// UX model (mirrors Kindle):
//   • Horizontal PageView slide — no page-curl gimmick
//   • Tap LEFT 30%  → previous entry
//   • Tap RIGHT 30% → next entry
//   • Tap CENTER / TOP → toggle toolbar (auto-hides after 3 s)
//   • Persistent progress bar at the bottom (entry N of total + scroll %)
//   • Full-page content per entry — scrollable within the page
//   • Cover page first (when opening a specific journal)
//
// Page order: [Cover?] [Entry₁] [Entry₂] … [EntryN]
class BookScreen extends ConsumerStatefulWidget {
  final int? folderId;
  const BookScreen({super.key, this.folderId});

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;

  // Decrypted entries — cover is index 0 when present, otherwise index 0 = first entry
  List<({Note note, Document doc})> _entries = [];
  Folder? _folder;
  bool _loading = true;

  // Current page index in the PageView
  int _pageIndex = 0;

  // Toolbar visibility (Kindle tap-to-show / auto-hide)
  bool _toolbarVisible = true;
  Timer? _hideTimer;

  // Scroll progress tracking for the progress bar
  // Updated by BookContentPage via callbacks
  double _scrollFraction = 0.0;

  // Whether the cover page is the first page (requires folderId != null)
  bool get _hasCover => _folder != null;

  // Index of the first entry page
  int get _entryPageOffset => _hasCover ? 1 : 0;

  // Total pages in the PageView
  int get _totalPages => _entries.length + _entryPageOffset;

  // Entry index (0-based) for current page, or -1 for cover
  int get _entryIndex => _pageIndex - _entryPageOffset;

  // True when currently on the cover page
  bool get _onCover => _hasCover && _pageIndex == 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _loadAndDecrypt();
    // Start with toolbar visible — it will auto-hide after initial delay
    _scheduleHide();
    // Use immersive mode while reading
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Restore system UI when leaving book view
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadAndDecrypt() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) {
      if (mounted) context.go('/lock');
      return;
    }

    Folder? folder;
    if (widget.folderId != null) {
      folder = await FolderService.getFolderById(widget.folderId!);
    }

    final notes = await NoteService.getNotes(folderId: widget.folderId);
    final entries = <({Note note, Document doc})>[];

    for (final note in notes) {
      try {
        final deltaJson = NoteService.decryptBody(note, masterKey);
        final doc = Document.fromJson(jsonDecode(deltaJson) as List);
        entries.add((note: note, doc: doc));
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _folder = folder;
        _loading = false;
      });
    }
  }

  // ── Toolbar auto-hide ───────────────────────────────────────────────────────

  void _showToolbar() {
    _hideTimer?.cancel();
    if (!_toolbarVisible) setState(() => _toolbarVisible = true);
    _scheduleHide();
  }

  void _toggleToolbar() {
    _hideTimer?.cancel();
    if (_toolbarVisible) {
      setState(() => _toolbarVisible = false);
    } else {
      setState(() => _toolbarVisible = true);
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _toolbarVisible) {
        setState(() => _toolbarVisible = false);
      }
    });
  }

  // ── Tap zone navigation ─────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails details, BuildContext context) {
    final size = MediaQuery.of(context).size;
    final x = details.globalPosition.dx;
    final leftZone = size.width * 0.28;
    final rightZone = size.width * 0.72;

    if (x < leftZone) {
      // Left tap → previous page only, no toolbar change
      _goToPrev();
    } else if (x > rightZone) {
      // Right tap → next page only, no toolbar change
      _goToNext();
    } else {
      // Center tap → toggle toolbar
      _toggleToolbar();
    }
  }

  void _goToNext() {
    if (_pageIndex < _totalPages - 1) {
      _pageController.animateToPage(
        _pageIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPrev() {
    if (_pageIndex > 0) {
      _pageController.animateToPage(
        _pageIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hushTheme = ref.watch(themeProvider);
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: hushTheme.pageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_folder?.name ?? 'Journal'),
          leading: const BackButton(),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.book_outlined,
                  size: 72, color: colors.outline),
              const SizedBox(height: 20),
              Text('No entries yet',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: colors.outline)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await context.push(
                      '/editor?folderId=${widget.folderId ?? 0}');
                  if (mounted) _loadAndDecrypt();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write first entry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JournalBackgroundWrapper(
        journalPresetId: _folder?.readingBgPresetId,
        journalImagePath: _folder?.readingBgImagePath,
        child: Stack(
        children: [
          // ── Page content ────────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTapDown(d, context),
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _pageIndex = index;
                  _scrollFraction = 0.0;
                });
              },
              itemCount: _totalPages,
              itemBuilder: (ctx, index) {
                if (_hasCover && index == 0) {
                  return BookCoverPage(
                    folder: _folder!,
                    entryCount: _entries.length,
                    theme: hushTheme,
                  );
                }
                final entry = _entries[index - _entryPageOffset];
                return BookContentPage(
                  note: entry.note,
                  doc: entry.doc,
                  theme: hushTheme,
                  entryNumber: index - _entryPageOffset + 1,
                  totalEntries: _entries.length,
                  onScrollFraction: (f) {
                    if (mounted) setState(() => _scrollFraction = f);
                  },
                );
              },
            ),
          ),

          // ── Tap-zone indicators (subtle, only while toolbar is visible) ────
          if (_toolbarVisible && !_onCover) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 80,
              width: MediaQuery.of(context).size.width * 0.28,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.chevron_left,
                        color: hushTheme.textSecondary.withValues(alpha: 0.3),
                        size: 28),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 80,
              width: MediaQuery.of(context).size.width * 0.28,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right,
                        color: hushTheme.textSecondary.withValues(alpha: 0.3),
                        size: 28),
                  ),
                ),
              ),
            ),
          ],

          // ── Top toolbar (Kindle-style auto-hide) ───────────────────────────
          AnimatedSlide(
            offset: _toolbarVisible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: _toolbarVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: _buildTopBar(context, hushTheme),
            ),
          ),

          // ── Bottom progress bar (always visible, Kindle-style) ─────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(context, hushTheme),
          ),
        ],
      ),    // Stack
      ),    // JournalBackgroundWrapper
    );      // Scaffold
  }

  Future<void> _showBackgroundPicker(BuildContext context, dynamic hushTheme) async {
    _hideTimer?.cancel(); // Keep toolbar visible while sheet is open
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _JournalBgPickerSheet(
        folder: _folder!,
        hushTheme: hushTheme,
        onPresetSelected: (presetId) async {
          await FolderService.setReadingBackground(
            _folder!.id!,
            presetId: presetId,
            imagePath: null,
          );
          final updated = await FolderService.getFolderById(_folder!.id!);
          if (mounted) setState(() => _folder = updated);
        },
        onImageSelected: (path) async {
          await FolderService.setReadingBackground(
            _folder!.id!,
            presetId: null,
            imagePath: path,
          );
          final updated = await FolderService.getFolderById(_folder!.id!);
          if (mounted) setState(() => _folder = updated);
        },
        onReset: () async {
          await FolderService.setReadingBackground(
            _folder!.id!,
            presetId: null,
            imagePath: null,
          );
          final updated = await FolderService.getFolderById(_folder!.id!);
          if (mounted) setState(() => _folder = updated);
        },
      ),
    );
    _scheduleHide();
  }

  Widget _buildTopBar(BuildContext context, dynamic hushTheme) {
    final title = _onCover
        ? (_folder?.name ?? 'Journal')
        : (_entryIndex >= 0 && _entryIndex < _entries.length
            ? _entries[_entryIndex].note.title
            : 'Journal');

    return Material(
      color: hushTheme.surface.withValues(alpha: 0.97),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Back',
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hushTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Background picker — only shown when a specific journal is open
              if (_folder != null)
                IconButton(
                  icon: Icon(
                    Icons.palette_outlined,
                    color: (_folder!.readingBgPresetId != null ||
                            _folder!.readingBgImagePath != null)
                        ? hushTheme.primary
                        : null,
                  ),
                  tooltip: 'Journal background',
                  onPressed: () => _showBackgroundPicker(context, hushTheme),
                ),
              if (!_onCover && _entryIndex >= 0 && _entryIndex < _entries.length)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit entry',
                  onPressed: () async {
                    final note = _entries[_entryIndex].note;
                    await context.push(
                        '/editor?noteId=${note.id}&folderId=${note.folderId}');
                    if (mounted) {
                      setState(() { _loading = true; _pageIndex = 0; });
                      _loadAndDecrypt();
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.add_outlined),
                tooltip: 'New entry',
                onPressed: () async {
                  await context.push(
                      '/editor?folderId=${widget.folderId ?? 0}');
                  if (mounted) {
                    setState(() { _loading = true; _pageIndex = 0; });
                    _loadAndDecrypt();
                  }
                },
              ),
            ],
          ),
        ),
      ), // JournalBackgroundWrapper
    );
  }

  Widget _buildProgressBar(BuildContext context, dynamic hushTheme) {
    // Entry-level progress (0.0 when on cover or first entry, 1.0 at last)
    final entryProgress = _entries.isEmpty
        ? 0.0
        : _onCover
            ? 0.0
            : ((_entryIndex + _scrollFraction) / _entries.length)
                .clamp(0.0, 1.0);

    final entryLabel = _onCover
        ? _folder?.name ?? 'Journal'
        : _entries.isNotEmpty && _entryIndex >= 0 && _entryIndex < _entries.length
            ? 'Entry ${_entryIndex + 1} of ${_entries.length}'
            : '';

    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin progress line — like Kindle's blue progress bar
          LinearProgressIndicator(
            value: entryProgress,
            minHeight: 2,
            backgroundColor: hushTheme.pageLines,
            valueColor: AlwaysStoppedAnimation<Color>(hushTheme.primary),
          ),
          // Label row — only when toolbar is visible
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _toolbarVisible
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          entryLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: hushTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(entryProgress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: hushTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(height: 2),
          ),
        ],
      ),
    );
  }
}

// ── Journal background picker bottom sheet ────────────────────────────────────
class _JournalBgPickerSheet extends StatelessWidget {
  final Folder folder;
  final dynamic hushTheme;
  final void Function(String presetId) onPresetSelected;
  final void Function(String path) onImageSelected;
  final VoidCallback onReset;

  const _JournalBgPickerSheet({
    required this.folder,
    required this.hushTheme,
    required this.onPresetSelected,
    required this.onImageSelected,
    required this.onReset,
  });

  bool _isActive(BackgroundPreset preset) {
    if (folder.readingBgPresetId == null) return false;
    return folder.readingBgPresetId == preset.id;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasCustomBg =
        folder.readingBgPresetId != null || folder.readingBgImagePath != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'JOURNAL BACKGROUND',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1.2, color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Overrides the global background for this journal only.',
                style: TextStyle(fontSize: 12, color: colors.outline),
              ),
              const SizedBox(height: 16),

              // Preset grid
              Wrap(
                spacing: 10, runSpacing: 10,
                children: kBackgroundPresets.map((preset) {
                  final isSelected = _isActive(preset);
                  final bg = preset.background;
                  Widget swatch;
                  if (bg.type == AppBackgroundType.gradient) {
                    swatch = Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: bg.gradientColors!,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? colors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    );
                  } else {
                    swatch = Container(
                      decoration: BoxDecoration(
                        color: bg.color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onPresetSelected(preset.id);
                    },
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 64, height: 48,
                            child: swatch,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? colors.primary
                                  : colors.outline,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Custom image
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Custom image from gallery'),
                subtitle: folder.readingBgImagePath != null
                    ? Text(
                        folder.readingBgImagePath!.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.primary, fontSize: 12),
                      )
                    : const Text('Use a photo as the reading background'),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final picked =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) onImageSelected(picked.path);
                },
              ),

              // Reset to global
              if (hasCustomBg) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.undo, color: colors.error),
                  title: Text('Use global background',
                      style: TextStyle(color: colors.error)),
                  subtitle: const Text(
                      'Removes this journal\'s override and uses the app-wide setting'),
                  onTap: () {
                    Navigator.pop(context);
                    onReset();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
