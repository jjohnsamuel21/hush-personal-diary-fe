import '../core/database/isar_service.dart';
import '../models/activity_log.dart';

/// Persists and retrieves activity log entries from the local SQLite database.
///
/// Design rules:
/// - Local logs may be individually deleted by the user.
/// - Shared logs represent the user's own session; deleting them does NOT
///   affect other collaborators' copies on their own devices.
/// - Logs are never uploaded to the server — they are always local-only.
class ActivityLogService {
  ActivityLogService._();

  /// Append a new log entry. Fire-and-forget safe — errors are silently swallowed
  /// so that a logging failure never disrupts the main flow.
  static Future<void> log({
    required String sessionType,
    String? noteId,
    required String action,
    String? noteTitle,
    String? detail,
  }) async {
    try {
      final db = DatabaseService.instance;
      await db.insert('activity_logs', {
        'session_type': sessionType,
        'note_id': noteId,
        'action': action,
        'note_title': noteTitle,
        'detail': detail,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Returns the most recent [limit] log entries, newest first.
  static Future<List<ActivityLog>> getLogs({int limit = 200}) async {
    final db = DatabaseService.instance;
    final rows = await db.query(
      'activity_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  /// Returns logs for a specific session type.
  static Future<List<ActivityLog>> getLogsByType(
    String sessionType, {
    int limit = 200,
  }) async {
    final db = DatabaseService.instance;
    final rows = await db.query(
      'activity_logs',
      where: 'session_type = ?',
      whereArgs: [sessionType],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  /// Deletes a single log entry (used for individual row swipe-delete).
  static Future<void> deleteLog(int id) async {
    final db = DatabaseService.instance;
    await db.delete('activity_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Clears all log entries for a given session type.
  static Future<void> clearLogsByType(String sessionType) async {
    final db = DatabaseService.instance;
    await db.delete('activity_logs',
        where: 'session_type = ?', whereArgs: [sessionType]);
  }

  /// Clears ALL log entries.
  static Future<void> clearAllLogs() async {
    final db = DatabaseService.instance;
    await db.delete('activity_logs');
  }
}
