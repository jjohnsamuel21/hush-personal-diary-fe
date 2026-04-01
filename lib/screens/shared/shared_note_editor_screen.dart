import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/shared_note.dart';
import '../../providers/shared_notes_provider.dart';

/// Editor / viewer for a shared note. Non-owners get a read-only view.
class SharedNoteEditorScreen extends ConsumerStatefulWidget {
  /// Non-null when editing an existing note; null when creating a new one.
  final String? noteId;

  const SharedNoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<SharedNoteEditorScreen> createState() =>
      _SharedNoteEditorScreenState();
}

class _SharedNoteEditorScreenState
    extends ConsumerState<SharedNoteEditorScreen> {
  SharedNote? _note;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.noteId == null) {
      // Creating a new note
      setState(() => _loading = false);
      return;
    }

    // Load from the provider cache first
    final cached = ref.read(sharedNotesProvider).valueOrNull;
    final note = cached?.firstWhere(
      (n) => n.id == widget.noteId,
      orElse: () => throw StateError('not found'),
    );

    if (note != null) {
      _titleCtrl.text = note.title;
      _bodyCtrl.text = note.body;
      setState(() {
        _note = note;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      if (widget.noteId == null) {
        // Create
        final created = await ref
            .read(sharedNotesNotifierProvider.notifier)
            .createNote(
              title: _titleCtrl.text.trim().isEmpty
                  ? 'Untitled'
                  : _titleCtrl.text.trim(),
              body: _bodyCtrl.text,
            );
        if (mounted && created != null) {
          context.go('/shared/editor?noteId=${created.id}');
        }
      } else {
        // Update
        await ref
            .read(sharedNotesNotifierProvider.notifier)
            .updateNote(
              widget.noteId!,
              title: _titleCtrl.text.trim().isEmpty
                  ? 'Untitled'
                  : _titleCtrl.text.trim(),
              body: _bodyCtrl.text,
            );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final readOnly = _note != null && !_note!.canEdit;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: readOnly
            ? const Text('Shared note')
            : TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'Note title…',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                readOnly: readOnly,
              ),
        actions: [
          if (_note != null && _note!.isOwner)
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Collaborators',
              onPressed: () =>
                  context.push('/shared/manage?noteId=${_note!.id}'),
            ),
          if (!readOnly) ...[
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_note != null && !_note!.isOwner)
                  MaterialBanner(
                    content: Text(
                      readOnly
                          ? 'You have read-only access to this note.'
                          : 'Shared by ${_note!.ownerDisplayName ?? _note!.ownerEmail}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    leading: Icon(
                      readOnly
                          ? Icons.visibility_outlined
                          : Icons.people_outline,
                      size: 20,
                    ),
                    backgroundColor: colors.secondaryContainer,
                    actions: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('OK'),
                      )
                    ],
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: TextField(
                      controller: _bodyCtrl,
                      maxLines: null,
                      expands: true,
                      readOnly: readOnly,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                          fontSize: 16, height: 1.65),
                      decoration: InputDecoration(
                        hintText: readOnly
                            ? null
                            : "Write something together…",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
