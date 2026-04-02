import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shared_note.dart';
import '../../providers/shared_notes_provider.dart';

/// Screen for note owners to invite collaborators and manage existing ones.
class ManageCollaboratorsScreen extends ConsumerStatefulWidget {
  final String noteId;
  const ManageCollaboratorsScreen({super.key, required this.noteId});

  @override
  ConsumerState<ManageCollaboratorsScreen> createState() =>
      _ManageCollaboratorsScreenState();
}

class _ManageCollaboratorsScreenState
    extends ConsumerState<ManageCollaboratorsScreen> {
  final _emailCtrl = TextEditingController();
  String _permission = 'edit';
  bool _inviting = false;
  String? _error;

  SharedNote? get _note =>
      ref.read(sharedNotesProvider).valueOrNull?.firstWhere(
            (n) => n.id == widget.noteId,
            orElse: () => throw StateError('not found'),
          );

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    // Cannot share a note that hasn't been synced to the server yet
    if (widget.noteId.startsWith('local_')) {
      setState(() => _error =
          'This note is saved offline only. Open it once while online to sync, then you can share it.');
      return;
    }

    setState(() {
      _inviting = true;
      _error = null;
    });

    final result = await ref
        .read(sharedNotesNotifierProvider.notifier)
        .shareNote(widget.noteId, emails: [email], permission: _permission);

    if (mounted) {
      setState(() => _inviting = false);
      if (result.isNotEmpty) {
        _emailCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to $email')),
        );
      } else {
        setState(() => _error =
            'Could not reach server. Check your connection and make sure the other person has a Hush account, then try again.');
      }
    }
  }

  Future<void> _remove(SharedNoteCollaborator collab) async {
    await ref
        .read(sharedNotesNotifierProvider.notifier)
        .removeCollaborator(widget.noteId, collab.shareId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = _note;
    final collaborators = note?.collaborators ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Collaborators')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Invite section ─────────────────────────────────────────────
          Text('Invite someone',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colors.primary)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    errorText: _error,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _InviteButton(
                loading: _inviting,
                onPressed: _invite,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Permission selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'edit',
                  label: Text('Can edit'),
                  icon: Icon(Icons.edit_outlined, size: 16)),
              ButtonSegment(
                  value: 'view',
                  label: Text('Can view'),
                  icon: Icon(Icons.visibility_outlined, size: 16)),
            ],
            selected: {_permission},
            onSelectionChanged: (s) =>
                setState(() => _permission = s.first),
            style: const ButtonStyle(
                visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 32),

          // ── Current collaborators ──────────────────────────────────────
          if (collaborators.isNotEmpty) ...[
            Text('People with access',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: colors.primary)),
            const SizedBox(height: 8),
            ...collaborators.map((c) => _CollaboratorTile(
                  collab: c,
                  onRemove: () => _remove(c),
                )),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'No collaborators yet',
                  style:
                      TextStyle(fontSize: 14, color: colors.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _InviteButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Invite'),
    );
  }
}

class _CollaboratorTile extends StatelessWidget {
  final SharedNoteCollaborator collab;
  final VoidCallback onRemove;
  const _CollaboratorTile({required this.collab, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final statusColor = switch (collab.status) {
      'accepted'  => colors.primary,
      'declined'  => colors.error,
      _           => colors.outline,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: colors.primaryContainer,
        backgroundImage: collab.avatarUrl != null
            ? NetworkImage(collab.avatarUrl!)
            : null,
        child: collab.avatarUrl == null
            ? Text(
                collab.email[0].toUpperCase(),
                style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600),
              )
            : null,
      ),
      title: Text(collab.displayName ?? collab.email,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(
        children: [
          Text(collab.email,
              style:
                  TextStyle(fontSize: 12, color: colors.outline)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              collab.status,
              style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              collab.permission,
              style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.person_remove_outlined,
            color: colors.error, size: 20),
        tooltip: 'Remove',
        onPressed: onRemove,
      ),
    );
  }
}
