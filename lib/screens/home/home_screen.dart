import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/folder.dart';
import '../../models/note.dart';
import '../../providers/folder_provider.dart';
import '../../providers/notes_provider.dart';
import '../../services/folder_service.dart';
import '../../services/note_service.dart';
import '../../widgets/common/app_background.dart';
import '../../widgets/folders/folder_card.dart';
import '../../widgets/notes/note_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hush',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Journals'),
            Tab(text: 'All Entries'),
          ],
        ),
      ),
      body: AppBackgroundWrapper(
        child: TabBarView(
          controller: _tabController,
          children: [
            _FolderGridTab(onFolderTap: _openFolder, onCreateFolder: _showCreateFolder),
            _AllNotesTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/editor?folderId=1'),
        tooltip: 'New entry',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Future<void> _openFolder(Folder folder) async {
    if (folder.isLocked) {
      final unlocked = await _showPinEntry(context, folder);
      if (!unlocked || !mounted) return;
    }
    if (mounted) context.push('/book?folderId=${folder.id}');
  }

  // Shows a PIN entry dialog; returns true if correct PIN entered.
  Future<bool> _showPinEntry(BuildContext ctx, Folder folder) async {
    return await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (_) => _PinEntryDialog(folder: folder),
        ) ??
        false;
  }

  void _showCreateFolder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateFolderSheet(ref: ref),
    );
  }
}

// ─── Folder grid tab ─────────────────────────────────────────────────────────
class _FolderGridTab extends ConsumerWidget {
  final void Function(Folder) onFolderTap;
  final VoidCallback onCreateFolder;

  const _FolderGridTab({required this.onFolderTap, required this.onCreateFolder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    // Batch query: all note counts in one round-trip instead of N.
    final countsAsync = ref.watch(folderNoteCountsProvider);
    final counts = countsAsync.valueOrNull ?? {};

    return foldersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (folders) => _buildGrid(context, ref, folders, counts),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<Folder> folders, Map<int, int> counts) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == folders.length) {
                  return _NewFolderCard(onTap: onCreateFolder);
                }
                final folder = folders[index];
                return FolderCard(
                  folder: folder,
                  noteCount: counts[folder.id] ?? 0,
                  onTap: () => onFolderTap(folder),
                  onLongPress: () => _showFolderOptions(context, ref, folder),
                );
              },
              childCount: folders.length + 1,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCoverImage(WidgetRef ref, Folder folder) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await FolderService.setCoverImage(folder.id!, picked.path);
    ref.invalidate(foldersProvider);
  }

  void _showFolderOptions(BuildContext context, WidgetRef ref, Folder folder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Set cover image
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Set cover image'),
              onTap: () async {
                Navigator.pop(context);
                await _pickCoverImage(ref, folder);
              },
            ),
            // Remove cover image
            if (folder.coverImagePath != null)
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('Remove cover image'),
                onTap: () async {
                  Navigator.pop(context);
                  await FolderService.setCoverImage(folder.id!, null);
                  ref.invalidate(foldersProvider);
                },
              ),
            const Divider(height: 8),
            // Set / Change PIN
            ListTile(
              leading: Icon(folder.isLocked
                  ? Icons.lock_reset_outlined
                  : Icons.lock_outline),
              title: Text(folder.isLocked ? 'Change PIN' : 'Set PIN'),
              onTap: () async {
                Navigator.pop(context);
                await _showSetPinDialog(context, ref, folder);
              },
            ),
            // Remove PIN
            if (folder.isLocked)
              ListTile(
                leading: const Icon(Icons.lock_open_outlined),
                title: const Text('Remove PIN'),
                onTap: () async {
                  Navigator.pop(context);
                  await FolderService.removePin(folder.id!);
                  ref.invalidate(foldersProvider);
                },
              ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete journal',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(foldersNotifierProvider.notifier)
                    .deleteFolder(folder.id!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetPinDialog(
      BuildContext context, WidgetRef ref, Folder folder) async {
    await showDialog(
      context: context,
      builder: (_) => _SetPinDialog(folder: folder, ref: ref),
    );
  }
}

// ─── All notes tab ────────────────────────────────────────────────────────────
class _AllNotesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AllNotesTab> createState() => _AllNotesTabState();
}

class _AllNotesTabState extends ConsumerState<_AllNotesTab>
    with AutomaticKeepAliveClientMixin {
  bool _reorderMode = false;
  List<Note> _reorderList = []; // used only in reorder mode

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notesAsync = ref.watch(notesProvider(null));
    final colors = Theme.of(context).colorScheme;

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (notes) {
        final visible = notes.where((n) => !n.isArchived).toList();
        if (visible.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 72, color: colors.outline),
                const SizedBox(height: 20),
                Text('No entries yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: colors.outline)),
                const SizedBox(height: 8),
                Text('Tap + to write your first entry',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.outline)),
              ],
            ),
          );
        }

        return Column(
          children: [
            // ── Toolbar: group / reorder toggle ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(
                      _reorderMode ? Icons.check_rounded : Icons.swap_vert_rounded,
                      size: 16,
                    ),
                    label: Text(_reorderMode ? 'Done' : 'Reorder'),
                    onPressed: () {
                      if (_reorderMode) {
                        // Persist the new order
                        final ids = _reorderList
                            .where((n) => n.id != null)
                            .map((n) => n.id!)
                            .toList();
                        NoteService.reorderNotes(ids).then((_) {
                          ref.invalidate(notesProvider);
                        });
                      } else {
                        // Sort: custom sort_order if set, else by updatedAt
                        _reorderList = List<Note>.from(visible)
                          ..sort((a, b) {
                            if (a.sortOrder != 0 || b.sortOrder != 0) {
                              final aSo = a.sortOrder == 0 ? 999999 : a.sortOrder;
                              final bSo = b.sortOrder == 0 ? 999999 : b.sortOrder;
                              return aSo.compareTo(bSo);
                            }
                            return b.updatedAt.compareTo(a.updatedAt);
                          });
                      }
                      setState(() => _reorderMode = !_reorderMode);
                    },
                  ),
                ],
              ),
            ),

            // ── Content: grouped or reorderable ──────────────────────────
            Expanded(
              child: _reorderMode
                  ? _buildReorderList()
                  : _buildGroupedList(visible),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReorderList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _reorderList.length,
      itemBuilder: (_, i) => ReorderableDragStartListener(
        key: ValueKey(_reorderList[i].id),
        index: i,
        child: NoteCard(note: _reorderList[i]),
      ),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _reorderList.removeAt(oldIndex);
          _reorderList.insert(newIndex, item);
        });
      },
    );
  }

  Widget _buildGroupedList(List<Note> notes) {
    final groups = _groupByDate(notes);
    final items = <_ListItem>[];
    for (final entry in groups.entries) {
      if (entry.value.isNotEmpty) {
        items.add(_ListItem.header(entry.key));
        items.addAll(entry.value.map(_ListItem.note));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isHeader) {
          return _GroupHeader(label: item.label!);
        }
        return NoteCard(note: item.note!);
      },
    );
  }

  // Groups notes into date buckets in display order.
  Map<String, List<Note>> _groupByDate(List<Note> notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    final pinned = <Note>[];
    final todayGroup = <Note>[];
    final weekGroup = <Note>[];
    final monthGroup = <Note>[];
    final older = <Note>[];

    for (final n in notes) {
      if (n.isPinned) { pinned.add(n); continue; }
      final d = DateTime(n.updatedAt.year, n.updatedAt.month, n.updatedAt.day);
      if (d == today) {
        todayGroup.add(n);
      } else if (d.isAfter(weekAgo)) {
        weekGroup.add(n);
      } else if (d.isAfter(monthAgo)) {
        monthGroup.add(n);
      } else {
        older.add(n);
      }
    }

    return {
      if (pinned.isNotEmpty) 'Pinned': pinned,
      if (todayGroup.isNotEmpty) 'Today': todayGroup,
      if (weekGroup.isNotEmpty) 'This Week': weekGroup,
      if (monthGroup.isNotEmpty) 'This Month': monthGroup,
      if (older.isNotEmpty) 'Older': older,
    };
  }
}

/// Flat item type for the grouped list builder.
class _ListItem {
  final String? label;
  final Note? note;
  bool get isHeader => label != null;

  const _ListItem.header(this.label) : note = null;
  const _ListItem.note(this.note) : label = null;
}

// ─── Date group header ────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ─── "New folder" placeholder card ───────────────────────────────────────────
class _NewFolderCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewFolderCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: colors.outline, size: 32),
            const SizedBox(height: 8),
            Text('New journal',
                style: TextStyle(color: colors.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── Create folder bottom sheet ───────────────────────────────────────────────
class _CreateFolderSheet extends StatefulWidget {
  final WidgetRef ref;
  const _CreateFolderSheet({required this.ref});

  @override
  State<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends State<_CreateFolderSheet> {
  final _nameController = TextEditingController();
  String _selectedColor = '#5C6BC0';
  String _selectedIcon = 'book';

  static const _colors = [
    '#5C6BC0', '#26C6DA', '#66BB6A', '#FFA726',
    '#EF5350', '#AB47BC', '#8D6E63', '#78909C',
  ];

  static const _icons = [
    // Everyday life
    'book', 'star', 'heart', 'home', 'work', 'school',
    // People & family
    'baby', 'family', 'friends', 'couple', 'pet', 'person',
    // Activities
    'travel', 'food', 'fitness', 'run', 'yoga', 'sport',
    // Hobbies
    'music', 'art', 'camera', 'movie', 'game', 'garden',
    // Nature & seasons
    'nature', 'sun', 'moon', 'rain', 'snow', 'flower',
    // Health & mind
    'health', 'mindfulness', 'sleep', 'mood', 'therapy', 'medicine',
    // Goals & ideas
    'goal', 'idea', 'money', 'career', 'gratitude', 'bucket',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Journal',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Journal name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text('Colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors.map((hex) {
              final color =
                  Color(int.parse(hex.replaceFirst('#', '0xFF')));
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: _selectedColor == hex
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Icon picker — 42 icons in a 6-column scrollable grid
          Text('Icon', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _icons.length,
              itemBuilder: (_, i) {
                final name = _icons[i];
                final selected = _selectedIcon == name;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = name),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                    child: Icon(_iconData(name), size: 22,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Create button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _create,
              child: const Text('Create Journal'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    await widget.ref
        .read(foldersNotifierProvider.notifier)
        .createFolder(name: name, color: _selectedColor, icon: _selectedIcon);
  }

  IconData _iconData(String name) {
    const map = <String, IconData>{
      // Everyday life
      'book':        Icons.menu_book_rounded,
      'star':        Icons.star_rounded,
      'heart':       Icons.favorite_rounded,
      'home':        Icons.home_rounded,
      'work':        Icons.work_rounded,
      'school':      Icons.school_rounded,
      // People & family
      'baby':        Icons.child_care_rounded,
      'family':      Icons.family_restroom_rounded,
      'friends':     Icons.group_rounded,
      'couple':      Icons.people_rounded,
      'pet':         Icons.pets_rounded,
      'person':      Icons.person_rounded,
      // Activities
      'travel':      Icons.flight_rounded,
      'food':        Icons.restaurant_rounded,
      'fitness':     Icons.fitness_center_rounded,
      'run':         Icons.directions_run_rounded,
      'yoga':        Icons.self_improvement_rounded,
      'sport':       Icons.sports_soccer_rounded,
      // Hobbies
      'music':       Icons.music_note_rounded,
      'art':         Icons.palette_rounded,
      'camera':      Icons.camera_alt_rounded,
      'movie':       Icons.movie_rounded,
      'game':        Icons.videogame_asset_rounded,
      'garden':      Icons.yard_rounded,
      // Nature & seasons
      'nature':      Icons.eco_rounded,
      'sun':         Icons.wb_sunny_rounded,
      'moon':        Icons.nightlight_rounded,
      'rain':        Icons.umbrella_rounded,
      'snow':        Icons.ac_unit_rounded,
      'flower':      Icons.local_florist_rounded,
      // Health & mind
      'health':      Icons.monitor_heart_rounded,
      'mindfulness': Icons.spa_rounded,
      'sleep':       Icons.bedtime_rounded,
      'mood':        Icons.mood_rounded,
      'therapy':     Icons.psychology_rounded,
      'medicine':    Icons.medication_rounded,
      // Goals & ideas
      'goal':        Icons.flag_rounded,
      'idea':        Icons.lightbulb_rounded,
      'money':       Icons.savings_rounded,
      'career':      Icons.trending_up_rounded,
      'gratitude':   Icons.volunteer_activism_rounded,
      'bucket':      Icons.format_list_bulleted_rounded,
    };
    return map[name] ?? Icons.folder_rounded;
  }
}

// ─── PIN entry dialog (unlock a locked journal) ───────────────────────────────
class _PinEntryDialog extends StatefulWidget {
  final Folder folder;
  const _PinEntryDialog({required this.folder});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text;
    if (pin.isEmpty) return;
    final ok = await FolderService.verifyPin(widget.folder.id!, pin);
    if (ok) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) setState(() => _error = 'Incorrect PIN. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.folder.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscure,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Enter PIN',
          border: const OutlineInputBorder(),
          errorText: _error,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

// ─── Set PIN dialog (create or change a journal PIN) ─────────────────────────
class _SetPinDialog extends StatefulWidget {
  final Folder folder;
  final WidgetRef ref;
  const _SetPinDialog({required this.folder, required this.ref});

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinController.text;
    final confirm = _confirmController.text;
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    await FolderService.setPin(widget.folder.id!, pin);
    widget.ref.invalidate(foldersProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.folder.isLocked ? 'Change PIN' : 'Set PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'New PIN (min 4 digits)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
