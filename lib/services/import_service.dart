import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'note_service.dart';

// Handles importing plain text and Markdown files as new diary entries.
class ImportService {
  /// Opens the file picker, reads the selected .md or .txt file, and creates
  /// a new note in the given folder.
  ///
  /// Returns the new note's id on success, or null if the user cancelled or
  /// the file could not be read.
  static Future<int?> importFile({
    required int folderId,
    required Uint8List masterKey,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final pf = result.files.first;
    final path = pf.path;
    if (path == null) return null;

    final raw = await File(path).readAsString();
    final title = _extractTitle(raw, pf.name);
    final deltaJson = _markdownToDelta(raw);

    final note = await NoteService.createNote(
      title: title,
      deltaJson: deltaJson,
      masterKey: masterKey,
      folderId: folderId,
    );
    return note.id;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// If the first line starts with "# ", use it as the title.
  /// Otherwise fall back to the filename without extension.
  static String _extractTitle(String text, String filename) {
    final first = text.split('\n').first.trim();
    if (first.startsWith('# ')) return first.substring(2).trim();
    return filename.replaceAll(RegExp(r'\.(md|txt)$'), '');
  }

  /// Converts a plain-text or Markdown string to a minimal Quill Delta JSON.
  /// Preserves headings (# → larger text via newline attribute), bold (**),
  /// italic (*), and plain paragraphs.
  static String _markdownToDelta(String markdown) {
    final ops = <Map<String, dynamic>>[];

    for (final line in markdown.split('\n')) {
      if (line.startsWith('### ')) {
        _addText(ops, '${line.substring(4)}\n', heading: 3);
      } else if (line.startsWith('## ')) {
        _addText(ops, '${line.substring(3)}\n', heading: 2);
      } else if (line.startsWith('# ')) {
        _addText(ops, '${line.substring(2)}\n', heading: 1);
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        _addText(ops, '${line.substring(2)}\n', listType: 'bullet');
      } else {
        // Inline bold/italic within the line
        _parseInline(ops, '$line\n');
      }
    }

    // Quill document must end with a bare newline op
    if (ops.isEmpty || ops.last['insert'] != '\n') {
      ops.add({'insert': '\n'});
    }

    return jsonEncode(ops);
  }

  static void _addText(
    List<Map<String, dynamic>> ops,
    String text, {
    int? heading,
    String? listType,
  }) {
    final attrs = <String, dynamic>{};
    if (heading != null) attrs['header'] = heading;
    if (listType != null) attrs['list'] = listType;

    ops.add({'insert': text});
    if (attrs.isNotEmpty) {
      ops.last['attributes'] = attrs;
    }
  }

  /// Very minimal inline Markdown parser: handles **bold** and *italic*.
  static void _parseInline(List<Map<String, dynamic>> ops, String line) {
    // Use regex to split on bold/italic markers
    final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    int lastEnd = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > lastEnd) {
        ops.add({'insert': line.substring(lastEnd, m.start)});
      }
      if (m.group(1) != null) {
        ops.add({
          'insert': m.group(1),
          'attributes': {'bold': true},
        });
      } else if (m.group(2) != null) {
        ops.add({
          'insert': m.group(2),
          'attributes': {'italic': true},
        });
      }
      lastEnd = m.end;
    }
    if (lastEnd < line.length) {
      ops.add({'insert': line.substring(lastEnd)});
    }
  }
}
