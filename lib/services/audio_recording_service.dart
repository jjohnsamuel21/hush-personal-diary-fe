import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Manages microphone recording and saving audio clips to the app's
/// documents directory.  All recording happens on-device — fully offline.
///
/// Usage:
///   final path = await AudioRecordingService.startRecording();
///   ...
///   final savedPath = await AudioRecordingService.stopRecording();
class AudioRecordingService {
  AudioRecordingService._();

  static AudioRecorder? _recorder;
  static bool _isRecording = false;

  static Future<bool> hasPermission() async {
    _recorder ??= AudioRecorder();
    return _recorder!.hasPermission();
  }

  /// Returns the output file path on success, or null if permission denied.
  static Future<String?> startRecording() async {
    _recorder ??= AudioRecorder();
    if (!await hasPermission()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio');
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${audioDir.path}/hush_audio_$timestamp.m4a';

    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _isRecording = true;
    return path;
  }

  /// Stops recording and returns the path to the saved file, or null.
  static Future<String?> stopRecording() async {
    if (_recorder == null || !_isRecording) return null;
    final path = await _recorder!.stop();
    _isRecording = false;
    return path;
  }

  /// Discards the current recording without saving.
  static Future<void> cancelRecording() async {
    if (_recorder == null || !_isRecording) return;
    await _recorder!.cancel();
    _isRecording = false;
  }

  static bool get isRecording => _isRecording;

  static Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
    _isRecording = false;
  }

  /// Permanently deletes an audio file from the device.
  static Future<void> deleteAudioFile(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}
