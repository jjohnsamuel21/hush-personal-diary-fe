import 'dart:convert';

// Plain Dart class — no code generation needed with sqflite.
// toMap() serializes to a Map for DB storage.
// fromMap() deserializes from a DB row back to a Note object.
class Note {
  final int? id;         // null before first save; set by SQLite autoincrement
  final int folderId;
  final String title;

  // Encrypted content — never stored as plain text
  final String encryptedBody;
  final String iv;       // 12-byte AES-GCM IV, base64
  final String authTag;  // 16-byte GCM tag, base64

  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;

  final int wordCount;
  final int readingTimeSec;

  final String coverColor;   // hex, e.g. "#5C6BC0"
  final String fontFamily;
  final int pageNumber;
  final int sortOrder;       // manual drag-to-reorder position (0 = default date order)

  // Page layout mode: 'text_only' | 'image_side' | 'collage'
  final String pageLayout;
  // Absolute file paths for layout images (up to 4), JSON-encoded list
  final List<String> layoutImages;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    this.id,
    required this.folderId,
    required this.title,
    required this.encryptedBody,
    required this.iv,
    required this.authTag,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.wordCount = 0,
    this.readingTimeSec = 0,
    this.coverColor = '#5C6BC0',
    this.fontFamily = 'Merriweather',
    this.pageNumber = 0,
    this.sortOrder = 0,
    this.pageLayout = 'text_only',
    this.layoutImages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Returns a copy of this Note with specified fields replaced.
  Note copyWith({
    int? id,
    int? folderId,
    String? title,
    String? encryptedBody,
    String? iv,
    String? authTag,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    int? wordCount,
    int? readingTimeSec,
    String? coverColor,
    String? fontFamily,
    int? pageNumber,
    int? sortOrder,
    String? pageLayout,
    List<String>? layoutImages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      encryptedBody: encryptedBody ?? this.encryptedBody,
      iv: iv ?? this.iv,
      authTag: authTag ?? this.authTag,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      wordCount: wordCount ?? this.wordCount,
      readingTimeSec: readingTimeSec ?? this.readingTimeSec,
      coverColor: coverColor ?? this.coverColor,
      fontFamily: fontFamily ?? this.fontFamily,
      pageNumber: pageNumber ?? this.pageNumber,
      sortOrder: sortOrder ?? this.sortOrder,
      pageLayout: pageLayout ?? this.pageLayout,
      layoutImages: layoutImages ?? this.layoutImages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'folder_id': folderId,
      'title': title,
      'encrypted_body': encryptedBody,
      'iv': iv,
      'auth_tag': authTag,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'word_count': wordCount,
      'reading_time_sec': readingTimeSec,
      'cover_color': coverColor,
      'font_family': fontFamily,
      'page_number': pageNumber,
      'sort_order': sortOrder,
      'page_layout': pageLayout,
      'layout_images': layoutImages.isEmpty ? null : jsonEncode(layoutImages),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    List<String> images = const [];
    final rawImages = map['layout_images'] as String?;
    if (rawImages != null && rawImages.isNotEmpty) {
      try {
        images = (jsonDecode(rawImages) as List).cast<String>();
      } catch (_) {}
    }
    return Note(
      id: map['id'] as int?,
      folderId: map['folder_id'] as int,
      title: map['title'] as String,
      encryptedBody: map['encrypted_body'] as String,
      iv: map['iv'] as String,
      authTag: map['auth_tag'] as String,
      isPinned: (map['is_pinned'] as int) == 1,
      isArchived: (map['is_archived'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
      wordCount: map['word_count'] as int,
      readingTimeSec: map['reading_time_sec'] as int,
      coverColor: map['cover_color'] as String,
      fontFamily: map['font_family'] as String,
      pageNumber: map['page_number'] as int,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      pageLayout: (map['page_layout'] as String?) ?? 'text_only',
      layoutImages: images,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
