import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

// Renders a BlockEmbed.image whose data is one of:
//   • A local file path (drawings from DrawingCanvasScreen)
//   • An http/https URL  (GIFs from GIPHY)
//   • An assets/ path   (bundled sticker PNGs when added in future)
class LocalImageEmbedBuilder extends EmbedBuilder {
  const LocalImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data as String;

    // Network URL (GIF or remote image)
    if (data.startsWith('http://') || data.startsWith('https://')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: data,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => _placeholder(
              context,
              Icons.broken_image_outlined,
              'Could not load image',
            ),
          ),
        ),
      );
    }

    // Bundled asset path
    if (data.startsWith('assets/')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(data, width: double.infinity, fit: BoxFit.fitWidth),
        ),
      );
    }

    // Local file path (drawing canvas output)
    final file = File(data);
    if (!file.existsSync()) {
      return _placeholder(context, Icons.broken_image_outlined, 'Drawing not found');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, width: double.infinity, fit: BoxFit.fitWidth),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer)),
        ],
      ),
    );
  }
}
