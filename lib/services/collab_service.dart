import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

/// A presence entry — one connected collaborator.
class CollabUser {
  final String id;
  final String name;
  final Color color;
  const CollabUser({required this.id, required this.name, required this.color});

  CollabUser copyWith({String? id, String? name, Color? color}) => CollabUser(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );
}

/// Tracks a remote collaborator's current cursor/selection.
class RemoteCursor {
  final String userId;
  final String name;
  final Color color;
  final int index;
  final int length;
  const RemoteCursor({
    required this.userId,
    required this.name,
    required this.color,
    required this.index,
    required this.length,
  });
}

/// Manages the WebSocket connection for live collaborative editing of a single
/// shared note.
///
/// Usage:
/// ```dart
/// final svc = CollabService(noteId: id);
/// svc.onRemoteDelta = (ops) { /* apply to QuillController */ };
/// svc.onPresenceChanged = (users) { setState(...) };
/// await svc.connect();
/// // when typing:
/// svc.sendDelta(delta);
/// // on selection change:
/// svc.sendCursor(index, length);
/// // on dispose:
/// await svc.disconnect();
/// ```
class CollabService {
  CollabService({required this.noteId});

  final String noteId;

  /// Called when a remote collaborator sends a delta. Apply it to the local
  /// QuillController via `document.compose(delta, ChangeSource.remote)`.
  void Function(List<dynamic> ops)? onRemoteDelta;

  /// Called whenever the presence list changes (user joined or left).
  void Function(List<CollabUser> users)? onPresenceChanged;

  /// Called when a remote cursor position arrives.
  void Function(RemoteCursor cursor)? onCursorChanged;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _pingTimer;
  bool _disposed = false;

  // ── Derived collaborator state ────────────────────────────────────────────

  List<CollabUser> _presence = [];

  /// Currently connected collaborators (including self after init).
  List<CollabUser> get presence => List.unmodifiable(_presence);

  // ── Connection ────────────────────────────────────────────────────────────

  /// Opens the WebSocket connection. Safe to call multiple times — no-ops if
  /// already connected. Returns silently if no JWT is stored (user signed out).
  Future<void> connect() async {
    if (_channel != null || _disposed) return;

    final token = await AuthService.getToken();
    if (token == null) return;

    final uri = Uri.parse('${_wsBase()}/ws/notes/$noteId?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _onDisconnected(),
        onDone: _onDisconnected,
        cancelOnError: false,
      );
      // Keepalive ping every 25s — Railway closes idle WS after ~30s.
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _send({'type': 'ping'});
      });
    } catch (_) {
      // Backend unreachable — editor still works via HTTP auto-save.
      _channel = null;
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _channel = null;
  }

  /// Closes the WebSocket. Call from the editor's dispose().
  Future<void> disconnect() async {
    _disposed = true;
    _pingTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _sub = null;
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  /// Broadcasts local Quill Delta ops to all other editors of this note.
  /// [ops] is the result of calling `delta.toJson()` on the local change.
  void sendDelta(List<dynamic> ops) {
    _send({'type': 'delta', 'ops': ops});
  }

  /// Broadcasts the local cursor/selection position.
  void sendCursor(int index, int length) {
    _send({'type': 'cursor', 'index': index, 'length': length});
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel == null || _disposed) return;
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  // ── Receive ───────────────────────────────────────────────────────────────

  void _handleMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'init':
          _handleInit(msg);
        case 'delta':
          onRemoteDelta?.call(msg['ops'] as List<dynamic>);
        case 'cursor':
          _handleCursor(msg);
        case 'presence':
          _handlePresence(msg);
      }
    } catch (_) {}
  }

  void _handleInit(Map<String, dynamic> msg) {
    _presence = (msg['presence'] as List<dynamic>)
        .map((e) => _parseUser(e as Map<String, dynamic>))
        .toList();
    onPresenceChanged?.call(_presence);
  }

  void _handleCursor(Map<String, dynamic> msg) {
    final userId = msg['user_id'] as String;
    final color = _colorFromHex(msg['color'] as String? ?? '#039BE5');
    final name = msg['name'] as String? ?? 'Unknown';
    onCursorChanged?.call(RemoteCursor(
      userId: userId,
      name: name,
      color: color,
      index: msg['index'] as int? ?? 0,
      length: msg['length'] as int? ?? 0,
    ));
  }

  void _handlePresence(Map<String, dynamic> msg) {
    final action = msg['action'] as String?;
    if (action == 'join') {
      final user = _parseUser(msg['user'] as Map<String, dynamic>);
      _presence = [..._presence.where((u) => u.id != user.id), user];
    } else if (action == 'leave') {
      final userId = msg['user_id'] as String;
      _presence = _presence.where((u) => u.id != userId).toList();
    }
    onPresenceChanged?.call(_presence);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  CollabUser _parseUser(Map<String, dynamic> data) => CollabUser(
        id: data['id'] as String,
        name: data['name'] as String,
        color: _colorFromHex(data['color'] as String? ?? '#039BE5'),
      );

  Color _colorFromHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  /// Converts the HTTP API URL to a WebSocket URL.
  static String _wsBase() {
    final apiUrl = dotenv.env['HUSH_API_URL'] ?? 'http://10.0.2.2:8000';
    if (apiUrl.startsWith('https://')) {
      return apiUrl.replaceFirst('https://', 'wss://');
    }
    return apiUrl.replaceFirst('http://', 'ws://');
  }
}
