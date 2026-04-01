import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/app_lock_notifier.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';
import '../services/note_service.dart';

// Riverpod provider for the list of notes.
// Widgets watch this to get the current note list and react when it changes.
//
// It's a FutureProvider because loading notes is async (DB read).
// The .family modifier means we can pass a folderId parameter:
//   ref.watch(notesProvider(null))      → all notes
//   ref.watch(notesProvider(1))         → notes in folder 1
final notesProvider = FutureProvider.family<List<Note>, int?>((ref, folderId) async {
  return NoteService.getNotes(folderId: folderId);
});

// StateNotifier that exposes note mutation operations (create/update/delete).
// After any mutation it calls ref.invalidate(notesProvider) to trigger a refresh
// of all widgets watching the notes list.
class NotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final Ref _ref;

  NotesNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    state = const AsyncValue.loading();
    try {
      final notes = await NoteService.getNotes();
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Uint8List? get _masterKey => _ref.read(masterKeyProvider);

  Future<void> createNote({required String deltaJson, String title = ''}) async {
    final key = _masterKey;
    if (key == null) return;
    await NoteService.createNote(
      title: title,
      deltaJson: deltaJson,
      masterKey: key,
    );
    await _loadNotes();
    // Also invalidate the family providers so FutureProvider.family watchers refresh
    _ref.invalidate(notesProvider);
  }

  Future<void> updateNote(Note note, String deltaJson, {String? title}) async {
    final key = _masterKey;
    if (key == null) return;
    await NoteService.updateNote(
      note: note,
      deltaJson: deltaJson,
      masterKey: key,
      title: title,
    );
    await _loadNotes();
    _ref.invalidate(notesProvider);
  }

  Future<void> deleteNote(Note note) async {
    await NoteService.softDelete(note);
    await _loadNotes();
    _ref.invalidate(notesProvider);
    _ref.invalidate(foldersProvider);
  }

  Future<void> pinNote(Note note, {required bool pinned}) async {
    await NoteService.pinNote(note, pinned: pinned);
    await _loadNotes();
    _ref.invalidate(notesProvider);
  }

  Future<void> archiveNote(Note note, {required bool archived}) async {
    await NoteService.archiveNote(note, archived: archived);
    await _loadNotes();
    _ref.invalidate(notesProvider);
  }

  Future<void> moveToFolder(Note note, int targetFolderId) async {
    final oldFolderId = note.folderId;
    await NoteService.moveToFolder(note, targetFolderId);
    await _loadNotes();
    _ref.invalidate(notesProvider(null));
    _ref.invalidate(notesProvider(oldFolderId));
    _ref.invalidate(notesProvider(targetFolderId));
    _ref.invalidate(foldersProvider);
  }

  Future<void> refresh() => _loadNotes();
}

final notesNotifierProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<List<Note>>>(
  (ref) => NotesNotifier(ref),
);
