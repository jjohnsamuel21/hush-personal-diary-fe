class Folder {
  final int? id;
  final String name;
  final String color;        // hex color
  final String icon;         // icon identifier string
  final bool isLocked;
  final String? encryptedFolderKey;
  final String? coverImagePath;        // absolute path to cover photo
  final String? readingBgPresetId;     // preset id from kBackgroundPresets (null = use global)
  final String? readingBgImagePath;    // custom image path for reading background
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Folder({
    this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.isLocked = false,
    this.encryptedFolderKey,
    this.coverImagePath,
    this.readingBgPresetId,
    this.readingBgImagePath,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'is_locked': isLocked ? 1 : 0,
      'encrypted_folder_key': encryptedFolderKey,
      'cover_image_path': coverImagePath,
      'reading_bg_preset_id': readingBgPresetId,
      'reading_bg_image_path': readingBgImagePath,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
      icon: map['icon'] as String,
      isLocked: (map['is_locked'] as int) == 1,
      encryptedFolderKey: map['encrypted_folder_key'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      readingBgPresetId: map['reading_bg_preset_id'] as String?,
      readingBgImagePath: map['reading_bg_image_path'] as String?,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
