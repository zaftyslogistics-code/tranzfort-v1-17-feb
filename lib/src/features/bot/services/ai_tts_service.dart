import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'ai_model_manager.dart';

/// Timing metrics for TTS performance analysis
class TtsTimingMetrics {
  final int phonemizeMs;
  final int inferenceMs;
  final int fileWriteMs;
  final int totalMs;
  final bool usedFallback; // Whether platform TTS was used instead of Kokoro
  final DateTime timestamp;

  TtsTimingMetrics({
    required this.phonemizeMs,
    required this.inferenceMs,
    required this.fileWriteMs,
    required this.totalMs,
    this.usedFallback = false,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final fallback = usedFallback ? ' [FALLBACK]' : '';
    return 'Phonemize: ${phonemizeMs}ms, Inference: ${inferenceMs}ms, File: ${fileWriteMs}ms, Total: ${totalMs}ms$fallback';
  }
}

/// On-device AI TTS using Piper via sherpa-onnx (fast, real-time).
///
/// Falls back to platform TTS for Hindi or if AI TTS fails.
/// API: [initialize], [isReady], [speak], [stop], [dispose].
class AiTtsService {
  static final AiTtsService _instance = AiTtsService._();
  factory AiTtsService() => _instance;
  AiTtsService._();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallbackTts = FlutterTts();
  bool _initialized = false;
  String? _cachePath;
  TtsTimingMetrics? _lastMetrics;

  bool get isInitialized => _initialized;

  /// Last timing metrics for diagnostics. Null if no speech generated yet.
  TtsTimingMetrics? get lastMetrics => _lastMetrics;

  /// True if Kokoro model is downloaded and user opted in
  bool get isReady {
    final mgr = AiModelManager();
    return mgr.isReady(AiModelType.tts) && mgr.useAiTts;
  }

  /// Initialize Piper TTS from downloaded ONNX model files.
  /// Returns false if model files not downloaded.
  Future<bool> initialize() async {
    if (_initialized) return true;

    final mgr = AiModelManager();
    final modelPath = await mgr.getModelPath(AiModelType.tts);
    if (modelPath == null) return false;

    try {
      final dirPath = await mgr.modelsPath;
      final modelDirPath = '$dirPath/vits-piper-en_US-lessac-medium';
      
      // Check required files exist in extracted directory
      final modelFile = File('$modelDirPath/en_US-lessac-medium.onnx');
      final tokensFile = File('$modelDirPath/tokens.txt');
      final dataDir = Directory('$modelDirPath/espeak-ng-data');
      
      if (!modelFile.existsSync() || !tokensFile.existsSync() || !dataDir.existsSync()) {
        debugPrint('AiTtsService: ERROR - required model files not found in $modelDirPath');
        return false;
      }

      debugPrint('AiTtsService: Initializing Piper TTS...');
      debugPrint('AiTtsService: Model: ${modelFile.path}');
      debugPrint('AiTtsService: Tokens: ${tokensFile.path}');
      debugPrint('AiTtsService: Data dir: ${dataDir.path}');

      // Configure sherpa-onnx TTS
      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelFile.path,
            tokens: tokensFile.path,
            dataDir: dataDir.path,
          ),
          numThreads: 4, // Use 4 threads for faster inference
          debug: false,
        ),
        ruleFsts: '',
        maxNumSenetences: 1,
      );

      _tts = sherpa.OfflineTts(config);
      
      final tempDir = await getTemporaryDirectory();
      _cachePath = '${tempDir.path}/ai_tts_cache';
      await Directory(_cachePath!).create(recursive: true);

      _initialized = true;
      debugPrint('AiTtsService: Piper TTS initialized successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('AiTtsService: init error: $e');
      debugPrint('AiTtsService: stack trace: $stackTrace');
      _tts = null;
      _initialized = false;
      return false;
    }
  }

  /// Speak text using Piper TTS for English, falling back to platform TTS for Hindi.
  /// [language] — 'en' or 'hi'.
  Future<void> speak(String text, String language) async {
    if (text.isEmpty) return;

    // For Hindi, always use platform TTS (Piper is English-only)
    if (language == 'hi') {
      await _speakWithFallback(text, 'hi');
      return;
    }

    // Try Piper TTS for English
    if (_initialized && _tts != null) {
      final stopwatch = Stopwatch()..start();
      int phonemizeMs = 0;
      int inferenceMs = 0;
      int fileWriteMs = 0;

      try {
        await _player.stop();

        // Generate speech using sherpa-onnx
        final p1 = stopwatch.elapsedMilliseconds;
        final audio = _tts!.generate(
          text: text,
          sid: 0, // Speaker ID (Piper models typically have 1 speaker)
          speed: 1.0,
        );
        phonemizeMs = stopwatch.elapsedMilliseconds - p1;

        if (audio.samples.isEmpty) {
          throw Exception('TTS generated empty audio');
        }

        // Write audio samples to a temp WAV file and play
        final p2 = stopwatch.elapsedMilliseconds;
        final wavPath = '$_cachePath/tts_output.wav';
        await _writeWav(audio.samples, wavPath, sampleRate: audio.sampleRate);
        await _player.setFilePath(wavPath);
        fileWriteMs = stopwatch.elapsedMilliseconds - p2;

        await _player.play();
        inferenceMs = stopwatch.elapsedMilliseconds - p1 - fileWriteMs;

        // Record metrics
        stopwatch.stop();
        _lastMetrics = TtsTimingMetrics(
          phonemizeMs: phonemizeMs,
          inferenceMs: inferenceMs,
          fileWriteMs: fileWriteMs,
          totalMs: stopwatch.elapsedMilliseconds,
          usedFallback: false,
        );
        debugPrint('AiTtsService: $_lastMetrics');
        return; // Success
      } catch (e) {
        debugPrint('AiTtsService: Piper TTS failed: $e');
        // Continue to fallback
      }
    }

    // Fallback to platform TTS
    await _speakWithFallback(text, language);
  }

  /// Fallback to platform TTS (flutter_tts)
  Future<void> _speakWithFallback(String text, String language) async {
    final stopwatch = Stopwatch()..start();
    try {
      debugPrint('AiTtsService: Using platform TTS fallback');
      await _fallbackTts.setLanguage(language == 'hi' ? 'hi-IN' : 'en-US');
      await _fallbackTts.setSpeechRate(0.9);
      await _fallbackTts.speak(text);
      stopwatch.stop();
      
      _lastMetrics = TtsTimingMetrics(
        phonemizeMs: 0,
        inferenceMs: 0,
        fileWriteMs: 0,
        totalMs: stopwatch.elapsedMilliseconds,
        usedFallback: true,
      );
    } catch (e) {
      debugPrint('AiTtsService: Fallback TTS also failed: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
    _tts?.free();
    _tts = null;
    _initialized = false;
  }

  /// Write raw float32 PCM samples to a WAV file.
  Future<void> _writeWav(
    List<double> samples,
    String path, {
    int sampleRate = 22050,
    int channels = 1,
    int bitsPerSample = 16,
  }) async {
    final numSamples = samples.length;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = numSamples * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // (space)
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    buffer.setUint16(offset, channels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Write samples as int16
    for (final sample in samples) {
      final clamped = sample.clamp(-1.0, 1.0);
      final int16 = (clamped * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, int16, Endian.little);
      offset += 2;
    }

    await File(path).writeAsBytes(buffer.buffer.asUint8List());
  }
}
