import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../core/database/isar_service.dart';
import '../core/crypto/encryption_service.dart';
import '../core/utils/text_utils.dart';
import '../models/note.dart';

// Sentinel used in updateNote so callers can distinguish "keep existing null" from
// "explicitly clear to null" for the nullable bg fields.
const _sentinel = Object();

/// Sort order for note lists.
enum NoteSortOrder { lastEdited, createdAt, alphabetical }

// All note CRUD operations go through this service.
// The service owns the encrypt-then-save and load-then-decrypt pipeline.
// Widgets and providers never touch encryption directly — they call NoteService.
class NoteService {
  // ───────────────── READ ─────────────────

  /// Returns all non-deleted notes, optionally filtered by [folderId].
  /// Pinned notes always appear first; then sorted by [sortOrder].
  static Future<List<Note>> getNotes({
    int? folderId,
    NoteSortOrder sortOrder = NoteSortOrder.lastEdited,
  }) async {
    final db = DatabaseService.instance;
    final whereClause = folderId != null
        ? 'is_deleted = 0 AND folder_id = ?'
        : 'is_deleted = 0';
    final whereArgs = folderId != null ? [folderId] : null;

    final dbOrderBy = switch (sortOrder) {
      NoteSortOrder.lastEdited   => 'is_pinned DESC, updated_at DESC',
      NoteSortOrder.createdAt    => 'is_pinned DESC, created_at DESC',
      NoteSortOrder.alphabetical => 'is_pinned DESC, title ASC',
    };

    final rows = await db.query(
      'notes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: dbOrderBy,
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Returns a single note by [id]. Returns null if not found.
  static Future<Note?> getNoteById(int id) async {
    final db = DatabaseService.instance;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  // ───────────────── DECRYPT ─────────────────

  /// Decrypts [note]'s encryptedBody using [masterKey].
  /// Returns the plain text Quill Delta JSON string.
  /// Call this when opening a note in the editor.
  static String decryptBody(Note note, Uint8List masterKey) {
    return EncryptionService.decrypt(
      EncryptedPayload(
        ciphertext: note.encryptedBody,
        iv: note.iv,
        authTag: note.authTag,
      ),
      masterKey,
    );
  }

  // ───────────────── CREATE ─────────────────

  /// Creates a new note.
  /// [deltaJson] is the plain text Quill Delta JSON — it will be encrypted before saving.
  /// [masterKey] is the in-memory key loaded after biometric unlock.
  static Future<Note> createNote({
    required String title,
    required String deltaJson,
    required Uint8List masterKey,
    int folderId = 0,
    String fontFamily = 'Merriweather',
    String pageLayout = 'text_only',
    List<String> layoutImages = const [],
    String? noteBgPresetId,
    String? noteBgImagePath,
  }) async {
    final now = DateTime.now();
    final payload = EncryptionService.encrypt(deltaJson, masterKey);
    final wordCount = TextUtils.countWords(_extractPlainText(deltaJson));

    final note = Note(
      folderId: folderId,
      title: title.isEmpty
          ? TextUtils.autoTitle(_extractPlainText(deltaJson), now)
          : title,
      encryptedBody: payload.ciphertext,
      iv: payload.iv,
      authTag: payload.authTag,
      wordCount: wordCount,
      readingTimeSec: TextUtils.readingTimeSec(wordCount),
      fontFamily: fontFamily,
      pageLayout: pageLayout,
      layoutImages: layoutImages,
      noteBgPresetId: noteBgPresetId,
      noteBgImagePath: noteBgImagePath,
      createdAt: now,
      updatedAt: now,
    );

    final db = DatabaseService.instance;
    final id = await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return note.copyWith(id: id);
  }

  // ───────────────── UPDATE ─────────────────

  /// Updates an existing note with new content.
  /// Re-encrypts the body with a fresh IV on every save.
  static Future<Note> updateNote({
    required Note note,
    required String deltaJson,
    required Uint8List masterKey,
    String? title,
    String? fontFamily,
    String? pageLayout,
    List<String>? layoutImages,
    Object? noteBgPresetId = _sentinel,
    Object? noteBgImagePath = _sentinel,
  }) async {
    final now = DateTime.now();
    final payload = EncryptionService.encrypt(deltaJson, masterKey);
    final wordCount = TextUtils.countWords(_extractPlainText(deltaJson));
    final plainText = _extractPlainText(deltaJson);

    final updated = note.copyWith(
      title: title ??
          (note.title.startsWith('Entry —')
              ? TextUtils.autoTitle(plainText, note.createdAt)
              : note.title),
      encryptedBody: payload.ciphertext,
      iv: payload.iv,
      authTag: payload.authTag,
      wordCount: wordCount,
      readingTimeSec: TextUtils.readingTimeSec(wordCount),
      fontFamily: fontFamily,
      pageLayout: pageLayout,
      layoutImages: layoutImages,
      noteBgPresetId: noteBgPresetId == _sentinel ? note.noteBgPresetId : noteBgPresetId as String?,
      noteBgImagePath: noteBgImagePath == _sentinel ? note.noteBgImagePath : noteBgImagePath as String?,
      updatedAt: now,
    );

    final db = DatabaseService.instance;
    await db.update('notes', updated.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
    return updated;
  }

  // ───────────────── DELETE ─────────────────

  /// Soft-deletes a note — it moves to trash but is not permanently removed.
  static Future<void> softDelete(Note note) async {
    final db = DatabaseService.instance;
    await db.update(
      'notes',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  /// Permanently deletes a note from the database.
  static Future<void> permanentDelete(int id) async {
    final db = DatabaseService.instance;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ───────────────── STATUS UPDATES ─────────────────

  /// Toggles the pinned state of a note without touching the encrypted body.
  static Future<Note> pinNote(Note note, {required bool pinned}) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notes',
      {'is_pinned': pinned ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [note.id],
    );
    return note.copyWith(isPinned: pinned, updatedAt: DateTime.now());
  }

  /// Toggles the archived state of a note.
  static Future<Note> archiveNote(Note note, {required bool archived}) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notes',
      {'is_archived': archived ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [note.id],
    );
    return note.copyWith(isArchived: archived, updatedAt: DateTime.now());
  }

  /// Moves a note to a different folder.
  static Future<Note> moveToFolder(Note note, int folderId) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'notes',
      {'folder_id': folderId, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [note.id],
    );
    return note.copyWith(folderId: folderId, updatedAt: DateTime.now());
  }

  /// Returns all archived notes (not deleted).
  static Future<List<Note>> getArchivedNotes() async {
    final rows = await DatabaseService.instance.query(
      'notes',
      where: 'is_archived = 1 AND is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Returns notes created on a specific date — used for the streak heatmap.
  /// Groups by calendar date (not exact time).
  static Future<Map<DateTime, int>> getNotesPerDay() async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT DATE(created_at) as day, COUNT(*) as cnt
      FROM notes
      WHERE is_deleted = 0
      GROUP BY DATE(created_at)
    ''');
    final map = <DateTime, int>{};
    for (final row in rows) {
      final parts = (row['day'] as String).split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      map[date] = row['cnt'] as int;
    }
    return map;
  }

  // ───────────────── REORDER ─────────────────

  /// Persists a new sort order for the given note IDs.
  /// [orderedIds] must be in the desired top-to-bottom display order.
  static Future<void> reorderNotes(List<int> orderedIds) async {
    final db = DatabaseService.instance;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        'notes',
        {'sort_order': i + 1},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  // ───────────────── HELPERS ─────────────────

  // Extracts plain text from a Quill Delta JSON string for word count and
  // auto-title purposes.  Each "insert" value is a JSON-encoded string, so we
  // jsonDecode the captured group so that escape sequences like \n become real
  // characters.  Without this, autoTitle receives literal backslash-n and
  // treats it as non-whitespace, producing "\n" titles.
  static String _extractPlainText(String deltaJson) {
    final regex = RegExp(r'"insert"\s*:\s*"((?:[^"\\]|\\.)*)"');
    final matches = regex.allMatches(deltaJson);
    return matches.map((m) {
      final raw = m.group(1) ?? '';
      try {
        // Wrap back in quotes so jsonDecode handles all JSON escape sequences.
        return jsonDecode('"$raw"') as String;
      } catch (_) {
        return raw;
      }
    }).join(' ');
  }
}
