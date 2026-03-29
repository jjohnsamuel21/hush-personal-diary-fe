import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/constants/app_constants.dart';
import '../../models/note.dart';
import '../../services/note_service.dart';
import '../../widgets/notes/note_card.dart';

// In-memory full-text search across all notes.
//
// All notes are decrypted once on screen open and stored in [_corpus].
// Searching filters [_corpus] in memory — no per-keystroke DB calls.
// The search query is debounced by [AppConstants.searchDebounceMs] so we
// don't filter hundreds of notes on every character typed.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;

  // All notes with their decrypted plain text — built once in initState
  List<({Note note, String plainText})> _corpus = [];
  List<Note> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildCorpus();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _buildCorpus() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;

    final notes = await NoteService.getNotes();
    final corpus = <({Note note, String plainText})>[];

    // Yield every 10 notes so the UI stays responsive during decryption.
    // AES-GCM decryption is CPU-bound; chunking prevents dropped frames.
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      try {
        final delta = NoteService.decryptBody(note, masterKey);
        final plain = _extractPlain(delta);
        corpus.add((note: note, plainText: '${note.title} $plain'.toLowerCase()));
      } catch (_) {
        // Decryption failure — skip note so it doesn't surface in results
      }
      if (i % 10 == 9) await Future.microtask(() {}); // yield to UI thread
    }

    if (mounted) {
      setState(() {
        _corpus = corpus;
        _loading = false;
      });
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      _runSearch,
    );
  }

  void _runSearch() {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final matched = _corpus
        .where((entry) => entry.plainText.contains(query))
        .map((entry) => entry.note)
        .toList();
    setState(() => _results = matched);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search your diary…',
            border: InputBorder.none,
            hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.outline),
          ),
        ),
        actions: [
          if (_queryController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _queryController.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Search across ${_corpus.length} '
              '${_corpus.length == 1 ? 'entry' : 'entries'}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No entries match "$query"',
          style:
              TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (_, i) => NoteCard(note: _results[i]),
    );
  }

  // Plain-text extractor for Quill Delta JSON — used for search matching only.
  // Decodes JSON string escapes so \n becomes a real newline, not a literal \n.
  String _extractPlain(String deltaJson) {
    final regex = RegExp(r'"insert"\s*:\s*"((?:[^"\\]|\\.)*)"');
    return regex.allMatches(deltaJson).map((m) {
      final raw = m.group(1) ?? '';
      try {
        return jsonDecode('"$raw"') as String;
      } catch (_) {
        return raw;
      }
    }).join(' ');
  }
}
