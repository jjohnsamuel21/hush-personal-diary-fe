import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../services/folder_service.dart';

// Simple read provider — used where only displaying folders (e.g. FolderGrid).
// Refreshed by calling ref.invalidate(foldersProvider).
final foldersProvider = FutureProvider<List<Folder>>((ref) {
  return FolderService.getFolders();
});

// Returns note counts for every folder in a single DB query.
// Watches foldersProvider so it auto-refreshes when folders change.
final folderNoteCountsProvider = FutureProvider<Map<int, int>>((ref) {
  ref.watch(foldersProvider); // re-run when folders are invalidated
  return FolderService.noteCountsAll();
});

// Mutable notifier — used when creating / updating / deleting folders.
class FoldersNotifier extends StateNotifier<AsyncValue<List<Folder>>> {
  final Ref _ref;
  FoldersNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await FolderService.getFolders());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Folder> createFolder({
    required String name,
    required String color,
    required String icon,
  }) async {
    final folder = await FolderService.createFolder(name: name, color: color, icon: icon);
    await _load();
    _ref.invalidate(foldersProvider);
    return folder;
  }

  Future<void> updateFolder(Folder folder) async {
    await FolderService.updateFolder(folder);
    await _load();
    _ref.invalidate(foldersProvider);
  }

  Future<void> deleteFolder(int id) async {
    await FolderService.deleteFolder(id);
    await _load();
    _ref.invalidate(foldersProvider);
  }
}

final foldersNotifierProvider =
    StateNotifierProvider<FoldersNotifier, AsyncValue<List<Folder>>>(
  (ref) => FoldersNotifier(ref),
);
