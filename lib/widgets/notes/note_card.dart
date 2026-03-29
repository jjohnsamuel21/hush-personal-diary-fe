import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/folder.dart';
import '../../models/note.dart';
import '../../providers/folder_provider.dart';
import '../../providers/notes_provider.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/utils/text_utils.dart';
import '../../services/note_service.dart';

// Reusable note card used on HomeScreen, SearchScreen, and BookScreen index.
// Long-press shows a context menu with pin / archive / move / delete actions.
class NoteCard extends ConsumerWidget {
  final Note note;
  const NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/viewer?noteId=${note.id}&folderId=${note.folderId}',
        ),
        onLongPress: () => _showContextMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Colored avatar
              CircleAvatar(
                backgroundColor: _hexColor(note.coverColor).withValues(alpha: 0.15),
                child: Icon(Icons.edit_note, color: _hexColor(note.coverColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_formatDate(note.updatedAt),
                            style: TextStyle(fontSize: 12, color: colors.outline)),
                        const SizedBox(width: 10),
                        Text('${note.wordCount} words',
                            style: TextStyle(fontSize: 12, color: colors.outline)),
                        const SizedBox(width: 10),
                        Text(TextUtils.formatReadingTime(note.readingTimeSec),
                            style: TextStyle(fontSize: 12, color: colors.outline)),
                      ],
                    ),
                  ],
                ),
              ),
              if (note.isPinned)
                Icon(Icons.push_pin, size: 16, color: colors.primary),
              if (note.isArchived)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.archive_outlined, size: 16, color: colors.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NoteContextMenu(note: note, ref: ref),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF5C6BC0);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Context menu bottom sheet ───────────────────────────────────────────────
class _NoteContextMenu extends ConsumerWidget {
  final Note note;
  final WidgetRef ref;
  const _NoteContextMenu({required this.note, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final notifier = ref.read(notesNotifierProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Rename
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, ref, notifier);
              },
            ),

            // Pin / Unpin
            ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(note.isPinned ? 'Unpin' : 'Pin to top'),
              onTap: () async {
                Navigator.pop(context);
                await notifier.pinNote(note, pinned: !note.isPinned);
              },
            ),

            // Archive / Unarchive
            ListTile(
              leading: Icon(
                note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              title: Text(note.isArchived ? 'Unarchive' : 'Archive'),
              onTap: () async {
                Navigator.pop(context);
                await notifier.archiveNote(note, archived: !note.isArchived);
              },
            ),

            // Move to folder
            foldersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (folders) {
                final others = folders.where((f) => f.id != note.folderId).toList();
                if (others.isEmpty) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.drive_file_move_outlined),
                  title: const Text('Move to folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _showFolderPicker(context, ref, others, notifier);
                  },
                );
              },
            ),

            const Divider(height: 8),

            // Delete
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await notifier.deleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    NotesNotifier notifier,
  ) {
    final controller = TextEditingController(text: note.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename entry'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) async {
            final newTitle = controller.text.trim();
            if (newTitle.isEmpty) return;
            Navigator.pop(ctx);
            final masterKey = ref.read(masterKeyProvider);
            if (masterKey == null) return;
            // Fetch fresh note so we have the current encrypted body
            final fresh = await NoteService.getNoteById(note.id!);
            if (fresh == null) return;
            final deltaJson = NoteService.decryptBody(fresh, masterKey);
            await NoteService.updateNote(
              note: fresh,
              deltaJson: deltaJson,
              masterKey: masterKey,
              title: newTitle,
            );
            ref.invalidate(notesProvider);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isEmpty) return;
              Navigator.pop(ctx);
              final masterKey = ref.read(masterKeyProvider);
              if (masterKey == null) return;
              final fresh = await NoteService.getNoteById(note.id!);
              if (fresh == null) return;
              final deltaJson = NoteService.decryptBody(fresh, masterKey);
              await NoteService.updateNote(
                note: fresh,
                deltaJson: deltaJson,
                masterKey: masterKey,
                title: newTitle,
              );
              ref.invalidate(notesProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFolderPicker(
    BuildContext context,
    WidgetRef ref,
    List<Folder> folders,
    NotesNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Move to…',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...folders.map((f) => ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f.name),
                  onTap: () async {
                    Navigator.pop(context);
                    await notifier.moveToFolder(note, f.id!);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
