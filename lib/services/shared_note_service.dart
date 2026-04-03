import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../core/database/isar_service.dart';
import '../models/shared_note.dart';
import 'auth_service.dart';

/// Extracts plain text from a Quill Delta JSON string.
/// Falls back to returning the original string if it is not Delta JSON.
String _deltaToPlainText(String body) {
  if (body.isNotEmpty && body.trimLeft().startsWith('[')) {
    try {
      final delta = jsonDecode(body) as List<dynamic>;
      final buf = StringBuffer();
      for (final op in delta) {
        if (op is Map && op['insert'] is String) buf.write(op['insert'] as String);
      }
      return buf.toString().trim();
    } catch (_) {}
  }
  return body;
}

/// API calls for shared notes + local SQLite cache management.
///
/// All notes fetched from the server are cached in the local `shared_notes`
/// table so the UI works while offline (read-only).
class SharedNoteService {
  SharedNoteService._();

  static String get _base =>
      dotenv.env['HUSH_API_URL'] ?? 'http://10.0.2.2:8000';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Fetch & sync ──────────────────────────────────────────────────────────

  /// Fetches shared notes from the server and replaces the local cache.
  /// Returns the fresh list on success, or the cached list on failure.
  /// Any notes saved locally while offline (id starts with `local_`) are
  /// pushed to the server first, then the cache is refreshed.
  static Future<List<SharedNote>> syncAndGetNotes() async {
    // Push any locally-created notes to the server before fetching.
    await _flushLocalNotes();

    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$_base/api/notes'), headers: headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List<dynamic>)
            .map((e) => SharedNote.fromApiJson(e as Map<String, dynamic>))
            .toList();

        await _replaceCache(list);
        return getCachedNotes(); // includes any local_ notes that failed to push
      }
    } catch (_) {
      // Network failure — fall through to cached results
    }

    return getCachedNotes();
  }

  /// Attempts to push any locally-created (offline) notes to the server.
  /// On success the local_ entry is replaced with the server-assigned ID.
  static Future<void> _flushLocalNotes() async {
    final db = DatabaseService.instance;
    final rows = await db.query(
      'shared_notes',
      where: "id LIKE 'local_%'",
    );
    if (rows.isEmpty) return;

    final headers = await _authHeaders();
    for (final row in rows) {
      final note = SharedNote.fromMap(row);
      try {
        final response = await http.post(
          Uri.parse('$_base/api/notes'),
          headers: headers,
          body: jsonEncode({
            'title': note.title,
            'body': _deltaToPlainText(note.body),
            'font_family': note.fontFamily,
            'cover_color': note.coverColor,
          }),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 201) {
          // Keep the original Delta JSON body in the local cache (the server
          // stores plain text; local cache stores Delta for rich editing).
          final serverNote = SharedNote.fromApiJson(
              jsonDecode(response.body) as Map<String, dynamic>)
              .copyWith(body: note.body);
          await db.delete('shared_notes', where: 'id = ?', whereArgs: [note.id]);
          await _upsertCache(serverNote);
        }
      } catch (_) {
        // Still offline — leave the local_ note in place
      }
    }
  }

  /// Returns notes from the local SQLite cache (no network call).
  static Future<List<SharedNote>> getCachedNotes() async {
    final db = DatabaseService.instance;
    final rows = await db.query(
      'shared_notes',
      where: 'is_archived = 0',
      orderBy: 'server_updated_at DESC',
    );
    return rows.map(SharedNote.fromMap).toList();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Creates a new shared note on the server and adds it to the local cache.
  /// If the backend is unreachable, saves locally with a temporary `local_` ID
  /// so the note is not lost. Local notes are pushed to the server on the
  /// next successful sync via [syncAndGetNotes].
  static Future<SharedNote> createNote({
    required String title,
    required String body,
    String fontFamily = 'Merriweather',
    String coverColor = '#5C6BC0',
  }) async {
    final headers = await _authHeaders();
    try {
      final response = await http.post(
        Uri.parse('$_base/api/notes'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'body': _deltaToPlainText(body), // backend stores plain text
          'font_family': fontFamily,
          'cover_color': coverColor,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 201) {
        // Store the Delta JSON body locally for rich editing; server gets plain text.
        final note = SharedNote.fromApiJson(
                jsonDecode(response.body) as Map<String, dynamic>)
            .copyWith(body: body);
        await _upsertCache(note);
        return note;
      }
    } catch (_) {}

    // Backend unreachable — persist locally so nothing is lost.
    // A local_ ID signals that this note has not been pushed to the server yet.
    final user = await AuthService.getCachedUser();
    final now = DateTime.now();
    final localNote = SharedNote(
      id: 'local_${now.millisecondsSinceEpoch}',
      ownerEmail: user?.email ?? '',
      ownerDisplayName: user?.displayName,
      ownerAvatarUrl: user?.avatarUrl,
      title: title,
      body: body,
      fontFamily: fontFamily,
      coverColor: coverColor,
      myPermission: 'owner',
      serverUpdatedAt: now,
      syncedAt: now,
    );
    await _upsertCache(localNote);
    return localNote;
  }

  /// Updates an existing shared note on the server and refreshes the cache.
  static Future<SharedNote?> updateNote(
    String noteId, {
    String? title,
    String? body,
    String? fontFamily,
    String? coverColor,
  }) async {
    final headers = await _authHeaders();
    // Backend gets plain text; local cache stores Delta JSON for rich editing.
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null) 'body': _deltaToPlainText(body),
      if (fontFamily != null) 'font_family': fontFamily,
      if (coverColor != null) 'cover_color': coverColor,
    };

    try {
      final response = await http.put(
        Uri.parse('$_base/api/notes/$noteId'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final serverNote =
            SharedNote.fromApiJson(jsonDecode(response.body) as Map<String, dynamic>);
        // Override body in local cache with the original Delta JSON
        final cachedNote = body != null ? serverNote.copyWith(body: body) : serverNote;
        await _upsertCache(cachedNote);
        return cachedNote;
      }
    } catch (_) {}

    // Offline — update local cache directly so the edit is not lost
    if (noteId.startsWith('local_') || body != null || title != null) {
      final db = DatabaseService.instance;
      final existing = await db.query(
          'shared_notes', where: 'id = ?', whereArgs: [noteId]);
      if (existing.isNotEmpty) {
        final current = SharedNote.fromMap(existing.first);
        final updated = current.copyWith(
          title: title,
          body: body,
          fontFamily: fontFamily,
          coverColor: coverColor,
        );
        await _upsertCache(updated);
        return updated;
      }
    }
    return null;
  }

  /// Permanently deletes a shared note (owner only).
  static Future<bool> deleteNote(String noteId) async {
    // Local-only notes never reached the server — just wipe from cache.
    if (noteId.startsWith('local_')) {
      await _removeFromCache(noteId);
      return true;
    }

    final headers = await _authHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$_base/api/notes/$noteId'),
        headers: headers,
      );
      if (response.statusCode == 204) {
        await _removeFromCache(noteId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Sharing ───────────────────────────────────────────────────────────────

  /// Shares a note with one or more email addresses.
  static Future<List<SharedNoteCollaborator>> shareNote(
    String noteId, {
    required List<String> emails,
    String permission = 'edit',
  }) async {
    final headers = await _authHeaders();
    try {
      final response = await http.post(
        Uri.parse('$_base/api/notes/$noteId/share'),
        headers: headers,
        body: jsonEncode({'emails': emails, 'permission': permission}),
      );

      if (response.statusCode == 201) {
        return (jsonDecode(response.body) as List<dynamic>)
            .map((e) =>
                SharedNoteCollaborator.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Removes a collaborator from a note (owner removes anyone; member removes self).
  static Future<bool> removeCollaborator(
      String noteId, String shareId) async {
    final headers = await _authHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$_base/api/notes/$noteId/share/$shareId'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ── Invites ───────────────────────────────────────────────────────────────

  /// Fetches pending invites for the current user.
  static Future<List<ShareInvite>> getInvites() async {
    final headers = await _authHeaders();
    try {
      final response = await http.get(
        Uri.parse('$_base/api/invites'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .map((e) => ShareInvite.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> acceptInvite(String shareId) async {
    final headers = await _authHeaders();
    try {
      final response = await http.post(
        Uri.parse('$_base/api/invites/$shareId/accept'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> declineInvite(String shareId) async {
    final headers = await _authHeaders();
    try {
      final response = await http.post(
        Uri.parse('$_base/api/invites/$shareId/decline'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Local cache helpers ───────────────────────────────────────────────────

  static Future<void> _replaceCache(List<SharedNote> notes) async {
    final db = DatabaseService.instance;
    final batch = db.batch();
    // Delete only server-synced notes; preserve local_ drafts pending upload.
    batch.delete('shared_notes', where: "id NOT LIKE 'local_%'");
    for (final note in notes) {
      batch.insert('shared_notes', note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upsertCache(SharedNote note) async {
    final db = DatabaseService.instance;
    await db.insert('shared_notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _removeFromCache(String noteId) async {
    final db = DatabaseService.instance;
    await db.delete('shared_notes', where: 'id = ?', whereArgs: [noteId]);
  }
}

