import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shared_note.dart';
import '../../providers/shared_notes_provider.dart';
import '../../services/shared_note_service.dart';

/// Displays pending share invites and lets the user accept or decline them.
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(invitesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Invites')),
      body: invitesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load invites',
              style: TextStyle(color: colors.outline)),
        ),
        data: (invites) {
          if (invites.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded,
                      size: 56, color: colors.outlineVariant),
                  const SizedBox(height: 16),
                  Text('No pending invites',
                      style: TextStyle(
                          fontSize: 16, color: colors.onSurface)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _InviteTile(invite: invites[i], ref: ref),
          );
        },
      ),
    );
  }
}

class _InviteTile extends StatefulWidget {
  final ShareInvite invite;
  final WidgetRef ref;
  const _InviteTile({required this.invite, required this.ref});

  @override
  State<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends State<_InviteTile> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    final ok = await SharedNoteService.acceptInvite(widget.invite.shareId);
    if (mounted) {
      setState(() => _loading = false);
      if (ok) {
        widget.ref.invalidate(invitesProvider);
        widget.ref.invalidate(sharedNotesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Joined "${widget.invite.noteTitle}"')),
        );
      }
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    await SharedNoteService.declineInvite(widget.invite.shareId);
    if (mounted) {
      setState(() => _loading = false);
      widget.ref.invalidate(invitesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final invite = widget.invite;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invite.noteTitle.isEmpty ? 'Untitled note' : invite.noteTitle,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'From ${invite.sharedByName ?? invite.sharedByEmail}  ·  ${invite.permission == 'edit' ? 'Can edit' : 'Can view'}',
              style:
                  TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  FilledButton(
                    onPressed: _accept,
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _decline,
                    child: const Text('Decline'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
