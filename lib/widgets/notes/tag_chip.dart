import 'package:flutter/material.dart';
import '../../models/tag.dart';

// A small colored chip displaying a tag name.
// Used on note cards and inside the editor tag row.
// Provide [onDeleted] to show an ✕ button (edit mode).
class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onDeleted;

  const TagChip({super.key, required this.tag, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(tag.color);
    return Chip(
      label: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onDeleted: onDeleted,
      deleteIconColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF5C6BC0);
    }
  }
}
