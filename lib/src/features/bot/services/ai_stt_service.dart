import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'ai_model_manager.dart';

/// Timing metrics for STT performance analysis
class SttTimingMetrics {
  final int recordStopMs; // Time to stop recording
  final int transcribeMs; // Whisper transcription time
  final int totalMs; // Total round-trip time
  final String? resultText; // What was recognized
  final DateTime timestamp;

  SttTimingMetrics({
    required this.recordStopMs,
    required this.transcribeMs,
    required this.totalMs,
    this.resultText,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final textPreview = resultText?.isNotEmpty == true
        ? resultText!.substring(0, resultText!.length.clamp(0, 30))
        : 'empty';
    return 'RecordStop: ${recordStopMs}ms, Transcribe: ${transcribeMs}ms, Total: ${totalMs}ms, Text: "$textPreview..."';
  }
}

/// On-device AI STT using Whisper Tiny via whisper_flutter_new.
///
/// Flow: record mic → WAV file → Whisper transcribe → return text.
/// Falls back to nothing — caller should use speech_to_text when unavailable.
/// API: [initialize], [isReady], [startRecording], [stopAndTranscribe], [cancel].
class AiSttService {
  static final AiSttService _instance = AiSttService._();
  factory AiSttService() => _instance;
  AiSttService._();

  Whisper? _whisper;
  final AudioRecorder _recorder = AudioRecorder();
  bool _initialized = false;
  bool _isRecording = false;
  String? _tempDir;
  SttTimingMetrics? _lastMetrics; // Store last timing for diagnostics

  bool get isInitialized => _initialized;
  bool get isRecording => _isRecording;

  /// Last timing metrics for diagnostics. Null if no transcription done yet.
  SttTimingMetrics? get lastMetrics => _lastMetrics;

  /// True if Whisper model is downloaded, user opted in, and service initialized.
  bool get isReady {
    final mgr = AiModelManager();
    return _initialized && mgr.isReady(AiModelType.stt) && mgr.useAiStt;
  }

  /// Initialize Whisper from downloaded model file.
  Future<bool> initialize() async {
    if (_initialized) return true;

    final mgr = AiModelManager();
    final modelPath = await mgr.getModelPath(AiModelType.stt);
    if (modelPath == null) return false;

    try {
      // Point Whisper to our ai_models directory where ggml-tiny.bin is downloaded
      final modelsDir = await mgr.modelsPath;
      _whisper = Whisper(
        model: WhisperModel.tiny,
        modelDir: modelsDir,
        downloadHost:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
      );

      final tempDir = await getTemporaryDirectory();
      _tempDir = tempDir.path;

      _initialized = true;
      debugPrint('AiSttService: Whisper initialized');
      return true;
    } catch (e) {
      debugPrint('AiSttService: init error: $e');
      _initialized = false;
      return false;
    }
  }

  /// Start recording audio from microphone.
  Future<bool> startRecording() async {
    if (!_initialized || _isRecording) return false;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final wavPath = '$_tempDir/stt_recording.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: wavPath,
      );

      _isRecording = true;
      debugPrint('AiSttService: recording started');
      return true;
    } catch (e) {
      debugPrint('AiSttService: startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and transcribe the audio.
  /// [language] — ignored; Whisper auto-detects language for Hinglish support (AI-07).
  /// Returns transcribed text, or null on failure.
  Future<String?> stopAndTranscribe({String language = 'en'}) async {
    if (!_isRecording) return null;

    final stopwatch = Stopwatch()..start();
    DateTime? t1;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      t1 = DateTime.now();

      if (path == null || !File(path).existsSync()) {
        debugPrint('AiSttService: no recording file');
        return null;
      }

      debugPrint('AiSttService: transcribing $path (auto-detect language)');

      // AI-07: No forced language — let Whisper auto-detect.
      // Truckers code-switch between Hindi and English (Hinglish).
      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: path,
          isTranslate: false,
          isNoTimestamps: true,
        ),
      );
      final t2 = DateTime.now();

      // Clean up temp file
      try {
        File(path).deleteSync();
      } catch (_) {}

      final text = result.text.trim();

      // Record metrics
      stopwatch.stop();
      _lastMetrics = SttTimingMetrics(
        recordStopMs: t1.difference(DateTime.now().subtract(Duration(milliseconds: stopwatch.elapsedMilliseconds))).inMilliseconds,
        transcribeMs: t2.difference(t1).inMilliseconds,
        totalMs: stopwatch.elapsedMilliseconds,
        resultText: text.isEmpty ? null : text,
      );
      debugPrint('AiSttService: $_lastMetrics');

      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('AiSttService: transcribe error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without transcribing.
  Future<void> cancel() async {
    if (_isRecording) {
      try {
        final path = await _recorder.stop();
        if (path != null) {
          try {
            File(path).deleteSync();
          } catch (_) {}
        }
      } catch (_) {}
      _isRecording = false;
    }
  }

  void dispose() {
    cancel();
    _recorder.dispose();
    _whisper = null;
    _initialized = false;
  }
}
