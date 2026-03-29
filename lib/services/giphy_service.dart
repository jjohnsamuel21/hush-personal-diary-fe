import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ── GIPHY integration ────────────────────────────────────────────────────────
// API key is loaded from .env at startup via flutter_dotenv.
// .env is gitignored — never commit the key to source control.
// Rate limits (free tier): 42 req/hour, 1000/day.
String get kGiphyApiKey => dotenv.env['GIPHY_API_KEY'] ?? '';

class GiphyGif {
  final String id;
  final String title;
  final String previewUrl; // small WebP thumbnail
  final String originalUrl; // full GIF URL to embed

  const GiphyGif({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.originalUrl,
  });

  factory GiphyGif.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>;
    final preview = images['fixed_width_small'] as Map<String, dynamic>;
    final original = images['original'] as Map<String, dynamic>;
    return GiphyGif(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      previewUrl: (preview['webp'] ?? preview['url']) as String,
      originalUrl: original['url'] as String,
    );
  }
}

class GiphyService {
  static const _baseUrl = 'https://api.giphy.com/v1/gifs';
  static const int _limit = 24;

  /// Search GIPHY for GIFs matching [query].
  /// Returns an empty list if the API key is not configured.
  static Future<List<GiphyGif>> search(String query) async {
    if (kGiphyApiKey.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'api_key': kGiphyApiKey,
      'q': query,
      'limit': '$_limit',
      'rating': 'g',
      'lang': 'en',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    return data.map((e) => GiphyGif.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch trending GIFs (shown before the user types anything).
  static Future<List<GiphyGif>> trending() async {
    if (kGiphyApiKey.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/trending').replace(queryParameters: {
      'api_key': kGiphyApiKey,
      'limit': '$_limit',
      'rating': 'g',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    return data.map((e) => GiphyGif.fromJson(e as Map<String, dynamic>)).toList();
  }
}
