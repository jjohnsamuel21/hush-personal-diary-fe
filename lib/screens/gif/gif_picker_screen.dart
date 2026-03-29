import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/giphy_service.dart';

// GIF picker screen — opened as a push route from the note editor.
// Returns the selected GIF URL (String) via Navigator.pop so the editor
// can insert it as a BlockEmbed.image.
//
// When kGiphyApiKey is empty, shows a "coming soon" banner instead.
class GifPickerScreen extends StatefulWidget {
  const GifPickerScreen({super.key});

  @override
  State<GifPickerScreen> createState() => _GifPickerScreenState();
}

class _GifPickerScreenState extends State<GifPickerScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  List<GiphyGif> _gifs = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kGiphyApiKey.isNotEmpty) _loadTrending();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await GiphyService.trending();
      if (mounted) setState(() { _gifs = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load GIFs'; _loading = false; });
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = _queryController.text.trim();
      if (q.isEmpty) {
        _loadTrending();
      } else {
        _search(q);
      }
    });
  }

  Future<void> _search(String query) async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await GiphyService.search(query);
      if (mounted) setState(() { _gifs = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Search failed'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: kGiphyApiKey.isEmpty
            ? const Text('GIF Picker')
            : TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search GIPHY…',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
      ),
      body: kGiphyApiKey.isEmpty ? _buildComingSoon() : _buildContent(),
    );
  }

  Widget _buildComingSoon() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gif_box_outlined,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 20),
            Text(
              'GIF support coming soon',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your GIPHY API key to kGiphyApiKey in\nlib/services/giphy_service.dart to enable GIF search.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_gifs.isEmpty) {
      return Center(
        child: Text('No GIFs found',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _gifs.length,
      itemBuilder: (_, i) {
        final gif = _gifs[i];
        return GestureDetector(
          onTap: () => Navigator.pop(context, gif.originalUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: gif.previewUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}
