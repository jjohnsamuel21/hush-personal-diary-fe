/// A single activity log entry — records user actions on notes.
///
/// Session types:
///   'local'  — private encrypted notes
///   'shared' — collaborative shared notes
///
/// Actions:
///   'created' | 'edited' | 'deleted' | 'shared' | 'audio_added' | 'invite_accepted'
class ActivityLog {
  final int id;
  final String sessionType; // 'local' | 'shared'
  final String? noteId;
  final String action;
  final String? noteTitle;
  final String? detail;
  final DateTime createdAt;

  const ActivityLog({
    required this.id,
    required this.sessionType,
    this.noteId,
    required this.action,
    this.noteTitle,
    this.detail,
    required this.createdAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) => ActivityLog(
        id: map['id'] as int,
        sessionType: map['session_type'] as String,
        noteId: map['note_id'] as String?,
        action: map['action'] as String,
        noteTitle: map['note_title'] as String?,
        detail: map['detail'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'session_type': sessionType,
        'note_id': noteId,
        'action': action,
        'note_title': noteTitle,
        'detail': detail,
        'created_at': createdAt.toIso8601String(),
      };

  /// Human-readable action label.
  String get actionLabel => switch (action) {
        'created'         => 'Created',
        'edited'          => 'Edited',
        'deleted'         => 'Deleted',
        'shared'          => 'Shared',
        'audio_added'     => 'Voice note added',
        'invite_accepted' => 'Invite accepted',
        _                 => action,
      };
}
