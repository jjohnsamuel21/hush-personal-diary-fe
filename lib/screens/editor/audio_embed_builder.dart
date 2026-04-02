import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_recording_service.dart';

/// Quill embed key used when inserting audio blocks.
const kAudioEmbedKey = 'audio';

/// Renders an inline audio player for [BlockEmbed] nodes with key 'audio'.
///
/// Embed data is the absolute path to the .m4a file.
/// Insert via:
///   ctrl.document.insert(index, BlockEmbed(kAudioEmbedKey, filePath));
class AudioEmbedBuilder extends EmbedBuilder {
  const AudioEmbedBuilder();

  @override
  String get key => kAudioEmbedKey;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final path = embedContext.node.value.data as String;

    return _AudioPlayerWidget(
      path: path,
      readOnly: embedContext.controller.readOnly,
      onDelete: embedContext.controller.readOnly
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete recording?'),
                  content: const Text(
                    'This will remove the audio clip from your note. '
                    'The file will be deleted from your device.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                // Delete the file from device
                await AudioRecordingService.deleteAudioFile(path);
                // Remove the embed from the document
                final offset = embedContext.node.documentOffset;
                embedContext.controller.replaceText(
                  offset,
                  1,
                  '',
                  TextSelection.collapsed(offset: offset),
                );
              }
            },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline audio player widget
// ─────────────────────────────────────────────────────────────────────────────

class _AudioPlayerWidget extends StatefulWidget {
  final String path;
  final bool readOnly;
  final VoidCallback? onDelete;

  const _AudioPlayerWidget({
    required this.path,
    required this.readOnly,
    this.onDelete,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = AudioPlayer();
    final file = File(widget.path);
    if (!file.existsSync()) {
      if (mounted) setState(() { _initialized = true; _hasError = true; });
      return;
    }
    try {
      final dur = await _player.setFilePath(widget.path);
      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _isPlaying = s.playing);
      });
      if (mounted) {
        setState(() {
          _duration = dur ?? Duration.zero;
          _initialized = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _initialized = true; _hasError = true; });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_duration > Duration.zero && _position >= _duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: _hasError ? _buildError(colors) : _buildPlayer(colors),
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Row(
      children: [
        Icon(Icons.mic_off_outlined, size: 18, color: colors.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Audio file not found',
            style: TextStyle(fontSize: 13, color: colors.outline),
          ),
        ),
        if (!widget.readOnly && widget.onDelete != null)
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.close_rounded, size: 18, color: colors.error),
          ),
      ],
    );
  }

  Widget _buildPlayer(ColorScheme colors) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Row(
      children: [
        // ── Play / Pause button ──────────────────────────────────────────
        GestureDetector(
          onTap: _initialized ? _togglePlayback : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _initialized ? colors.primary : colors.outline,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: colors.onPrimary,
              size: 22,
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── Progress + timestamps ────────────────────────────────────────
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: colors.primary,
                  inactiveTrackColor: colors.primary.withValues(alpha: 0.25),
                  thumbColor: colors.primary,
                  overlayColor: colors.primary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: progress.toDouble(),
                  onChanged: _initialized
                      ? (v) async {
                          final ms =
                              (v * _duration.inMilliseconds).toInt();
                          await _player
                              .seek(Duration(milliseconds: ms));
                        }
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position),
                        style: TextStyle(
                            fontSize: 10, color: colors.outline)),
                    Text(_fmt(_duration),
                        style: TextStyle(
                            fontSize: 10, color: colors.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 4),

        // ── Mic icon ─────────────────────────────────────────────────────
        Icon(Icons.mic_rounded,
            size: 15, color: colors.primary.withValues(alpha: 0.55)),

        // ── Delete button (edit mode only) ───────────────────────────────
        if (!widget.readOnly && widget.onDelete != null) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.close_rounded,
                size: 17, color: colors.outline),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recording sheet — big simple UI designed for one-hand / driving use
// ─────────────────────────────────────────────────────────────────────────────

class AudioRecorderSheet extends StatefulWidget {
  /// Called when recording is complete — [path] is the saved .m4a file path,
  /// or null if the user cancelled or an error occurred.
  final void Function(String? path) onDone;

  const AudioRecorderSheet({super.key, required this.onDone});

  @override
  State<AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<AudioRecorderSheet>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _waiting = false; // debounce busy state
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && _recording) {
          _pulseCtrl.reverse();
        } else if (s == AnimationStatus.dismissed && _recording) {
          _pulseCtrl.forward();
        }
      });
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    // If user dismisses sheet mid-recording, cancel it
    if (_recording) AudioRecordingService.cancelRecording();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_waiting) return;
    setState(() => _waiting = true);
    final path = await AudioRecordingService.startRecording();
    if (!mounted) return;
    if (path == null) {
      // Permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission required. Enable it in Settings → Apps → Hush.',
          ),
        ),
      );
      setState(() => _waiting = false);
      return;
    }
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    _pulseCtrl.forward();
    setState(() {
      _recording = true;
      _waiting = false;
    });
  }

  Future<void> _stopRecording() async {
    if (_waiting || !_recording) return;
    setState(() => _waiting = true);
    _timer?.cancel();
    _pulseCtrl.reset();
    final savedPath = await AudioRecordingService.stopRecording();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _waiting = false;
    });
    widget.onDone(savedPath);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _pulseCtrl.reset();
    if (_recording) await AudioRecordingService.cancelRecording();
    if (mounted) widget.onDone(null);
  }

  String _fmtElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ────────────────────────────────────────────────────
            Text(
              _recording ? 'Recording…' : 'Voice Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _recording ? colors.error : colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // ── Timer ────────────────────────────────────────────────────
            Text(
              _fmtElapsed(_elapsed),
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
                color: _recording ? colors.error : colors.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _recording
                  ? 'Tap the button to stop'
                  : 'Tap the button to start',
              style: TextStyle(fontSize: 13, color: colors.outline),
            ),
            const SizedBox(height: 32),

            // ── Big record / stop button ──────────────────────────────────
            GestureDetector(
              onTap: _waiting
                  ? null
                  : (_recording ? _stopRecording : _startRecording),
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _recording ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? colors.error : colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? colors.error : colors.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _waiting
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          ),
                        )
                      : Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Cancel ───────────────────────────────────────────────────
            TextButton.icon(
              onPressed: _waiting ? null : _cancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: colors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
