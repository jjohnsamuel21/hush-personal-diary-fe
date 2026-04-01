import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shared_note.dart';
import '../../providers/shared_notes_provider.dart';
import '../../widgets/common/app_background.dart';

class SharedNotesScreen extends ConsumerWidget {
  const SharedNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(sharedNotesProvider);
    final invitesAsync = ref.watch(invitesProvider);
    final colors = Theme.of(context).colorScheme;

    final pendingCount = invitesAsync.valueOrNull?.length ?? 0;

    return AppBackgroundWrapper(
      child: CustomScrollView(
        slivers: [
          // ── Invites banner ───────────────────────────────────────────────
          if (pendingCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Badge(
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.mail_outline_rounded),
                    ),
                    title: const Text('Pending invites'),
                    subtitle: Text(
                      pendingCount == 1
                          ? '1 person shared a note with you'
                          : '$pendingCount people shared notes with you',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/shared/invites'),
                  ),
                ),
              ),
            ),

          // ── Notes list ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: notesAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 48, color: colors.outline),
                      const SizedBox(height: 12),
                      Text('Could not load shared notes',
                          style: TextStyle(color: colors.outline)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(sharedNotesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 64, color: colors.outlineVariant),
                          const SizedBox(height: 16),
                          Text('No shared notes yet',
                              style: TextStyle(
                                  fontSize: 17,
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                            'Create one and invite collaborators.',
                            style: TextStyle(
                                fontSize: 13, color: colors.outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SharedNoteCard(note: notes[index]),
                    childCount: notes.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared note card ──────────────────────────────────────────────────────────

class _SharedNoteCard extends ConsumerWidget {
  final SharedNote note;
  const _SharedNoteCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final color = _hexColor(note.coverColor) ?? colors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/shared/editor?noteId=${note.id}'),
        onLongPress: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _PermissionBadge(permission: note.myPermission),
                ],
              ),
              const SizedBox(height: 8),

              // ── Body preview ───────────────────────────────────────────
              Text(
                note.body,
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // ── Footer: owner + collaborators ─────────────────────────
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 14, color: colors.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note.isOwner
                          ? 'Owned by you'
                          : note.ownerDisplayName ?? note.ownerEmail,
                      style:
                          TextStyle(fontSize: 12, color: colors.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.collaborators.isNotEmpty) ...[
                    Icon(Icons.people_outline,
                        size: 14, color: colors.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${note.collaborators.length}',
                      style:
                          TextStyle(fontSize: 12, color: colors.outline),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SharedNoteOptions(note: note, ref: ref),
    );
  }

  Color? _hexColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ── Permission badge ──────────────────────────────────────────────────────────

class _PermissionBadge extends StatelessWidget {
  final String permission;
  const _PermissionBadge({required this.permission});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, bg) = switch (permission) {
      'owner' => ('Owner', colors.primaryContainer),
      'edit'  => ('Editor', colors.secondaryContainer),
      _       => ('Viewer', colors.surfaceContainerHighest),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurface)),
    );
  }
}

// ── Options sheet ─────────────────────────────────────────────────────────────

class _SharedNoteOptions extends ConsumerWidget {
  final SharedNote note;
  final WidgetRef ref;
  const _SharedNoteOptions({required this.note, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(context);
              context.push('/shared/editor?noteId=${note.id}');
            },
          ),
          if (note.isOwner) ...[
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Manage collaborators'),
              onTap: () {
                Navigator.pop(context);
                context.push('/shared/manage?noteId=${note.id}');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(context);
                final ok = await ref
                    .read(sharedNotesNotifierProvider.notifier)
                    .deleteNote(note.id);
                if (context.mounted && !ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not delete note')),
                  );
                }
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.exit_to_app_outlined),
              title: const Text('Leave shared note'),
              onTap: () async {
                Navigator.pop(context);
                // Find the user's own share row
                final myShare = note.collaborators.firstWhere(
                  (c) => c.status == 'accepted',
                  orElse: () => note.collaborators.first,
                );
                await ref
                    .read(sharedNotesNotifierProvider.notifier)
                    .removeCollaborator(note.id, myShare.shareId);
              },
            ),
          ],
        ],
      ),
    );
  }
}
