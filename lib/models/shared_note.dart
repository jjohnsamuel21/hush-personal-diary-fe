import 'dart:convert';

/// A single collaborator on a shared note.
class SharedNoteCollaborator {
  final String shareId;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String permission; // 'edit' | 'view'
  final String status;     // 'pending' | 'accepted' | 'declined'

  const SharedNoteCollaborator({
    required this.shareId,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.permission,
    required this.status,
  });

  factory SharedNoteCollaborator.fromJson(Map<String, dynamic> json) =>
      SharedNoteCollaborator(
        shareId: json['share_id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        permission: json['permission'] as String,
        status: json['status'] as String,
      );

  Map<String, dynamic> toJson() => {
        'share_id': shareId,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'permission': permission,
        'status': status,
      };
}

/// A shared note — stored in plaintext on the server and cached locally.
///
/// IMPORTANT: These are intentionally NOT encrypted. Shared notes are a
/// separate feature from private diary entries (which are AES-256-GCM
/// encrypted on-device). The user explicitly chooses to make a note shared,
/// understanding it is stored on the server.
class SharedNote {
  final String id; // Server UUID
  final String ownerEmail;
  final String? ownerDisplayName;
  final String? ownerAvatarUrl;
  final String title;
  final String body; // plaintext
  final String fontFamily;
  final String coverColor;
  final bool isArchived;
  final String myPermission; // 'owner' | 'edit' | 'view'
  final List<SharedNoteCollaborator> collaborators;
  final DateTime serverUpdatedAt;
  final DateTime syncedAt;

  const SharedNote({
    required this.id,
    required this.ownerEmail,
    this.ownerDisplayName,
    this.ownerAvatarUrl,
    required this.title,
    required this.body,
    this.fontFamily = 'Merriweather',
    this.coverColor = '#5C6BC0',
    this.isArchived = false,
    this.myPermission = 'owner',
    this.collaborators = const [],
    required this.serverUpdatedAt,
    required this.syncedAt,
  });

  bool get isOwner => myPermission == 'owner';
  bool get canEdit => myPermission == 'owner' || myPermission == 'edit';

  // ── API JSON ──────────────────────────────────────────────────────────────

  factory SharedNote.fromApiJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>;
    final collabs = (json['collaborators'] as List<dynamic>? ?? [])
        .map((e) => SharedNoteCollaborator.fromJson(e as Map<String, dynamic>))
        .toList();

    return SharedNote(
      id: json['id'] as String,
      ownerEmail: owner['email'] as String,
      ownerDisplayName: owner['display_name'] as String?,
      ownerAvatarUrl: owner['avatar_url'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      fontFamily: json['font_family'] as String? ?? 'Merriweather',
      coverColor: json['cover_color'] as String? ?? '#5C6BC0',
      isArchived: json['is_archived'] as bool? ?? false,
      myPermission: json['my_permission'] as String? ?? 'owner',
      collaborators: collabs,
      serverUpdatedAt: DateTime.parse(json['updated_at'] as String),
      syncedAt: DateTime.now(),
    );
  }

  // ── SQLite cache ──────────────────────────────────────────────────────────

  factory SharedNote.fromMap(Map<String, dynamic> map) {
    final collabJson =
        map['collaborators_json'] as String? ?? '[]';
    final collabs = (jsonDecode(collabJson) as List<dynamic>)
        .map((e) => SharedNoteCollaborator.fromJson(e as Map<String, dynamic>))
        .toList();

    return SharedNote(
      id: map['id'] as String,
      ownerEmail: map['owner_email'] as String,
      ownerDisplayName: map['owner_display_name'] as String?,
      ownerAvatarUrl: map['owner_avatar_url'] as String?,
      title: map['title'] as String,
      body: map['body'] as String,
      fontFamily: map['font_family'] as String,
      coverColor: map['cover_color'] as String,
      isArchived: (map['is_archived'] as int) == 1,
      myPermission: map['my_permission'] as String,
      collaborators: collabs,
      serverUpdatedAt: DateTime.parse(map['server_updated_at'] as String),
      syncedAt: DateTime.parse(map['synced_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_email': ownerEmail,
        'owner_display_name': ownerDisplayName,
        'owner_avatar_url': ownerAvatarUrl,
        'title': title,
        'body': body,
        'font_family': fontFamily,
        'cover_color': coverColor,
        'is_archived': isArchived ? 1 : 0,
        'my_permission': myPermission,
        'collaborators_json':
            jsonEncode(collaborators.map((c) => c.toJson()).toList()),
        'server_updated_at': serverUpdatedAt.toIso8601String(),
        'synced_at': syncedAt.toIso8601String(),
      };

  SharedNote copyWith({
    String? title,
    String? body,
    String? fontFamily,
    String? coverColor,
    bool? isArchived,
    String? myPermission,
    List<SharedNoteCollaborator>? collaborators,
  }) =>
      SharedNote(
        id: id,
        ownerEmail: ownerEmail,
        ownerDisplayName: ownerDisplayName,
        ownerAvatarUrl: ownerAvatarUrl,
        title: title ?? this.title,
        body: body ?? this.body,
        fontFamily: fontFamily ?? this.fontFamily,
        coverColor: coverColor ?? this.coverColor,
        isArchived: isArchived ?? this.isArchived,
        myPermission: myPermission ?? this.myPermission,
        collaborators: collaborators ?? this.collaborators,
        serverUpdatedAt: serverUpdatedAt,
        syncedAt: syncedAt,
      );
}

/// A pending share invite the current user has received.
class ShareInvite {
  final String shareId;
  final String noteId;
  final String noteTitle;
  final String sharedByEmail;
  final String? sharedByName;
  final String permission;
  final DateTime createdAt;

  const ShareInvite({
    required this.shareId,
    required this.noteId,
    required this.noteTitle,
    required this.sharedByEmail,
    this.sharedByName,
    required this.permission,
    required this.createdAt,
  });

  factory ShareInvite.fromJson(Map<String, dynamic> json) => ShareInvite(
        shareId: json['share_id'] as String,
        noteId: json['note_id'] as String,
        noteTitle: json['note_title'] as String,
        sharedByEmail: json['shared_by_email'] as String,
        sharedByName: json['shared_by_name'] as String?,
        permission: json['permission'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
