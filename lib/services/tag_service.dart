import '../core/database/isar_service.dart';
import '../models/tag.dart';

class TagService {
  static Future<List<Tag>> getAllTags() async {
    final db = DatabaseService.instance;
    final rows = await db.query('tags', orderBy: 'name ASC');
    return rows.map(Tag.fromMap).toList();
  }

  static Future<Tag> createTag({
    required String name,
    String color = '#5C6BC0',
  }) async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final map = Tag(name: name, color: color, createdAt: now).toMap();
    final id = await db.insert('tags', map);
    return Tag.fromMap({...map, 'id': id});
  }

  static Future<void> deleteTag(int id) async {
    // ON DELETE CASCADE removes matching note_tags rows automatically
    await DatabaseService.instance.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  // Returns all tags assigned to a note.
  static Future<List<Tag>> getTagsForNote(int noteId) async {
    final db = DatabaseService.instance;
    final rows = await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN note_tags nt ON nt.tag_id = t.id
      WHERE nt.note_id = ?
      ORDER BY t.name ASC
    ''', [noteId]);
    return rows.map(Tag.fromMap).toList();
  }

  // Replaces the tag assignments for a note with the given list of tag IDs.
  // Uses a transaction so partial updates can't leave the join table in a bad state.
  static Future<void> setTagsForNote(int noteId, List<int> tagIds) async {
    final db = DatabaseService.instance;
    await db.transaction((txn) async {
      await txn.delete('note_tags', where: 'note_id = ?', whereArgs: [noteId]);
      for (final tagId in tagIds) {
        await txn.insert('note_tags', {'note_id': noteId, 'tag_id': tagId});
      }
    });
  }
}
