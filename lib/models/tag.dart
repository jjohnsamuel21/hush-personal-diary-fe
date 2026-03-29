// Plain Dart class following the same toMap/fromMap pattern as Note and Folder.
class Tag {
  final int? id;
  final String name;
  final String color; // hex e.g. "#5C6BC0"
  final DateTime createdAt;

  const Tag({
    this.id,
    required this.name,
    this.color = '#5C6BC0',
    required this.createdAt,
  });

  Tag copyWith({int? id, String? name, String? color, DateTime? createdAt}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
