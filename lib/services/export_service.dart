import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/crypto/encryption_service.dart';
import '../models/note.dart';
import 'note_service.dart';

class ExportService {
  // ── PDF ─────────────────────────────────────────────────────────────────────

  /// Export a single note as a PDF and open the system share sheet.
  static Future<void> exportNotePdf(Note note, Uint8List masterKey) async {
    final deltaJson = NoteService.decryptBody(note, masterKey);
    final plainText = _deltaToPlainText(deltaJson);
    final pdf = _buildPdf([note], [plainText]);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${_safeName(note.title)}.pdf',
    );
  }

  /// Export all notes in a folder as a single PDF and open the share sheet.
  static Future<void> exportJournalPdf(
    int? folderId,
    Uint8List masterKey,
  ) async {
    final notes = await NoteService.getNotes(folderId: folderId);
    final texts = <String>[];
    final validNotes = <Note>[];
    for (final n in notes) {
      try {
        final delta = NoteService.decryptBody(n, masterKey);
        texts.add(_deltaToPlainText(delta));
        validNotes.add(n);
      } catch (_) {}
    }
    if (validNotes.isEmpty) return;
    final pdf = _buildPdf(validNotes, texts);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'hush_journal.pdf',
    );
  }

  static pw.Document _buildPdf(List<Note> notes, List<String> texts) {
    final pdf = pw.Document();
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final text = texts[i];
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(note.title,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                _formatDate(note.createdAt),
                style: pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey600),
              ),
              pw.Divider(),
            ],
          ),
          build: (_) => [
            pw.Text(text, style: const pw.TextStyle(fontSize: 13)),
          ],
        ),
      );
    }
    return pdf;
  }

  // ── Encrypted ZIP ────────────────────────────────────────────────────────────

  /// Exports all notes as a JSON-encoded, AES-256-GCM encrypted ZIP file.
  /// The ZIP is saved to the app's documents directory and shared via the
  /// share sheet. The user can import it back by decrypting with the same key.
  static Future<void> exportEncryptedZip(Uint8List masterKey) async {
    final notes = await NoteService.getNotes();

    // Collect raw (still-encrypted) note maps — no decryption needed for backup
    final List<Map<String, dynamic>> rows =
        notes.map((n) => n.toMap()).toList();
    final jsonBytes = utf8.encode(jsonEncode(rows));

    // Encrypt the JSON bytes with the master key
    final payload = EncryptionService.encrypt(
      String.fromCharCodes(jsonBytes),
      masterKey,
    );

    // Pack into a ZIP archive
    final archive = Archive();
    archive.addFile(
      ArchiveFile('notes.json.enc', payload.ciphertext.length,
          utf8.encode(payload.ciphertext)),
    );
    archive.addFile(
      ArchiveFile('meta.json', 0,
          utf8.encode(jsonEncode({'iv': payload.iv, 'authTag': payload.authTag}))),
    );

    final zipBytes = ZipEncoder().encode(archive)!;

    // Save to a temp file and share
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hush_backup.zip');
    await file.writeAsBytes(zipBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Hush encrypted backup',
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _deltaToPlainText(String deltaJson) {
    try {
      final List ops = jsonDecode(deltaJson) as List;
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map && op['insert'] is String) {
          buffer.write(op['insert']);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  static String _safeName(String title) =>
      title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');

  static String _formatDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
