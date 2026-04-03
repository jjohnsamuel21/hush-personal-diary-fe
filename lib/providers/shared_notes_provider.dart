import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_note.dart';
import '../services/shared_note_service.dart';
import 'auth_provider.dart';

/// Fetches (and caches) shared notes. Only active when signed in.
final sharedNotesProvider =
    FutureProvider<List<SharedNote>>((ref) async {
  final isSignedIn = ref.watch(isGoogleSignedInProvider);
  if (!isSignedIn) return [];
  return SharedNoteService.syncAndGetNotes();
});

/// Manages mutations on shared notes (create / update / delete / share).
class SharedNotesNotifier
    extends StateNotifier<AsyncValue<List<SharedNote>>> {
  final Ref _ref;

  SharedNotesNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final notes = await SharedNoteService.syncAndGetNotes();
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<SharedNote> createNote({
    required String title,
    required String body,
    String fontFamily = 'Merriweather',
    String coverColor = '#5C6BC0',
  }) async {
    final note = await SharedNoteService.createNote(
      title: title,
      body: body,
      fontFamily: fontFamily,
      coverColor: coverColor,
    );
    // Update state immediately with the new note prepended — no waiting for server round-trip.
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([note, ...current]);
    // Background refresh to get server-assigned ID / collaborator info.
    _load();
    return note;
  }

  Future<SharedNote?> updateNote(
    String noteId, {
    String? title,
    String? body,
    String? fontFamily,
    String? coverColor,
  }) async {
    final note = await SharedNoteService.updateNote(
      noteId,
      title: title,
      body: body,
      fontFamily: fontFamily,
      coverColor: coverColor,
    );
    if (note != null) {
      // Patch in-memory list immediately — no full reload needed.
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((n) => n.id == noteId ? note : n).toList(),
      );
    }
    return note;
  }

  Future<bool> deleteNote(String noteId) async {
    final ok = await SharedNoteService.deleteNote(noteId);
    if (ok) {
      // Remove from state immediately.
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(current.where((n) => n.id != noteId).toList());
    }
    return ok;
  }

  Future<List<SharedNoteCollaborator>> shareNote(
    String noteId, {
    required List<String> emails,
    String permission = 'edit',
  }) async {
    final result = await SharedNoteService.shareNote(
      noteId,
      emails: emails,
      permission: permission,
    );
    if (result.isNotEmpty) _ref.invalidate(sharedNotesProvider);
    return result;
  }

  Future<bool> removeCollaborator(String noteId, String shareId) async {
    final ok =
        await SharedNoteService.removeCollaborator(noteId, shareId);
    if (ok) _ref.invalidate(sharedNotesProvider);
    return ok;
  }
}

final sharedNotesNotifierProvider = StateNotifierProvider<
    SharedNotesNotifier, AsyncValue<List<SharedNote>>>(
  (ref) => SharedNotesNotifier(ref),
);

/// Pending invites for the current user.
final invitesProvider = FutureProvider<List<ShareInvite>>((ref) async {
  final isSignedIn = ref.watch(isGoogleSignedInProvider);
  if (!isSignedIn) return [];
  return SharedNoteService.getInvites();
});
