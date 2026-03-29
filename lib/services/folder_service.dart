import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../core/database/isar_service.dart';
import '../models/folder.dart';

class FolderService {
  static Future<List<Folder>> getFolders() async {
    final db = DatabaseService.instance;
    final rows = await db.query(
      'folders',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Folder.fromMap).toList();
  }

  static Future<Folder?> getFolderById(int id) async {
    final db = DatabaseService.instance;
    final rows = await db.query('folders', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Folder.fromMap(rows.first);
  }

  static Future<Folder> createFolder({
    required String name,
    required String color,
    required String icon,
  }) async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final sortOrder = await _nextSortOrder(db);
    final map = Folder(
      name: name,
      color: color,
      icon: icon,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    ).toMap();

    final id = await db.insert('folders', map);
    return Folder.fromMap({...map, 'id': id});
  }

  static Future<Folder> updateFolder(Folder folder) async {
    final db = DatabaseService.instance;
    final updated = folder.copyWith(updatedAt: DateTime.now());
    await db.update(
      'folders',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
    return updated;
  }

  static Future<void> deleteFolder(int id) async {
    final db = DatabaseService.instance;
    // Move any notes in this folder to the General folder (id = 1)
    await db.update(
      'notes',
      {'folder_id': 1},
      where: 'folder_id = ?',
      whereArgs: [id],
    );
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // Returns the note count for a given folder — shown on FolderCard badges.
  static Future<int> noteCount(int folderId) async {
    final db = DatabaseService.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM notes WHERE folder_id = ? AND is_deleted = 0',
      [folderId],
    );
    return result.first['cnt'] as int;
  }

  // Returns note counts for ALL folders in a single query.
  // Use this instead of calling noteCount() once per card to avoid N DB round-trips.
  static Future<Map<int, int>> noteCountsAll() async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT folder_id, COUNT(*) AS cnt
      FROM notes
      WHERE is_deleted = 0
      GROUP BY folder_id
    ''');
    return {for (final r in rows) r['folder_id'] as int: r['cnt'] as int};
  }

  // ── PIN protection ──────────────────────────────────────────────────────────

  /// Sets a PIN on the folder.  Stores SHA-256(salt + pin) as the pin hash.
  static Future<void> setPin(int folderId, String pin) async {
    final hash = _hashPin(folderId, pin);
    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.update(
      'folders',
      {'is_locked': 1, 'encrypted_folder_key': 'pin:$hash', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  /// Removes PIN protection from the folder.
  static Future<void> removePin(int folderId) async {
    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.update(
      'folders',
      {'is_locked': 0, 'encrypted_folder_key': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  /// Returns true if the supplied PIN matches the stored hash.
  static Future<bool> verifyPin(int folderId, String pin) async {
    final rows = await DatabaseService.instance.query(
      'folders',
      columns: ['encrypted_folder_key'],
      where: 'id = ?',
      whereArgs: [folderId],
    );
    if (rows.isEmpty) return false;
    final stored = rows.first['encrypted_folder_key'] as String?;
    if (stored == null || !stored.startsWith('pin:')) return false;
    final storedHash = stored.substring(4);
    return storedHash == _hashPin(folderId, pin);
  }

  /// SHA-256(folderId_salt + pin) → hex string.
  static String _hashPin(int folderId, String pin) {
    final digest = SHA256Digest();
    final input = utf8.encode('hush_folder_${folderId}_$pin');
    return digest.process(Uint8List.fromList(input))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Sets (or clears) the cover image path for a folder.
  static Future<void> setCoverImage(int folderId, String? path) async {
    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.update(
      'folders',
      {'cover_image_path': path, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  static Future<int> _nextSortOrder(dynamic db) async {
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM folders',
    );
    return result.first['next'] as int;
  }
}

// Folder model needs copyWith — add it here as an extension to avoid
// touching the model file (which doesn't have copyWith yet).
extension FolderCopyWith on Folder {
  Folder copyWith({
    int? id,
    String? name,
    String? color,
    String? icon,
    bool? isLocked,
    String? encryptedFolderKey,
    String? coverImagePath,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isLocked: isLocked ?? this.isLocked,
      encryptedFolderKey: encryptedFolderKey ?? this.encryptedFolderKey,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
