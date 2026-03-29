import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../services/tag_service.dart';

// All tags — used by the tag picker and settings screen.
final tagsProvider = FutureProvider<List<Tag>>((ref) {
  return TagService.getAllTags();
});

// Tags for a specific note — family keyed by noteId.
// Pass noteId as the parameter: ref.watch(noteTagsProvider(noteId))
final noteTagsProvider = FutureProvider.family<List<Tag>, int>((ref, noteId) {
  return TagService.getTagsForNote(noteId);
});

class TagsNotifier extends StateNotifier<AsyncValue<List<Tag>>> {
  final Ref _ref;
  TagsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await TagService.getAllTags());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Tag> createTag({required String name, String color = '#5C6BC0'}) async {
    final tag = await TagService.createTag(name: name, color: color);
    await _load();
    _ref.invalidate(tagsProvider);
    return tag;
  }

  Future<void> deleteTag(int id) async {
    await TagService.deleteTag(id);
    await _load();
    _ref.invalidate(tagsProvider);
  }
}

final tagsNotifierProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<Tag>>>(
  (ref) => TagsNotifier(ref),
);
