import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI model types managed by this service.
enum AiModelType { llm, tts, stt }

/// Available LLM model options
enum LlmOption { none, tinyLlama }

/// Status of a single AI model.
enum AiModelStatus { notDownloaded, downloading, ready, error }

/// Info about a single AI model for UI display.
class AiModelInfo {
  final AiModelType type;
  final String label;
  final String description;
  final String estimatedSize;
  final AiModelStatus status;
  final double downloadProgress;
  final int? fileSizeBytes;
  final bool isSelectable;
  final bool isSelected;

  const AiModelInfo({
    required this.type,
    required this.label,
    required this.description,
    required this.estimatedSize,
    this.status = AiModelStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.fileSizeBytes,
    this.isSelectable = false,
    this.isSelected = false,
  });
}

/// Manages on-demand download, deletion, and status of all AI models.
///
/// v3.0 — Simplified: Only TinyLlama LLM, Kokoro TTS, Whisper STT.
/// Each model is independently downloadable and deletable.
class AiModelManager extends ChangeNotifier {
  static final AiModelManager _instance = AiModelManager._();
  factory AiModelManager() => _instance;
  AiModelManager._();

  static const _modelsDir = 'ai_models';

  // ── Pref keys ──────────────────────────────────────────────────────────────
  static const _prefUseAiLlm = 'ai_use_llm';
  static const _prefUseAiTts = 'ai_use_tts';
  static const _prefUseAiStt = 'ai_use_stt';

  // ── Model definitions ──────────────────────────────────────────────────────
  // LLM: TinyLlama 1.1B Chat (only option)
  static const _tinyLlamaFile = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  static const _tinyLlamaRepo = 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF';
  static const _tinyLlamaSize = 600 * 1024 * 1024; // ~600MB

  // TTS: Piper TTS (fast, real-time, English) via sherpa-onnx
  static const ttsArchiveFileName = 'vits-piper-en_US-lessac-medium.tar.bz2';
  static const ttsModelFileName = 'en_US-lessac-medium.onnx';
  static const ttsTokensFileName = 'tokens.txt';
  static const ttsDataDirName = 'espeak-ng-data';
  static const _ttsUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2';
  static const ttsEstimatedBytes = 65 * 1024 * 1024; // ~65MB (compressed archive)

  // STT: Whisper Tiny
  static const sttFileName = 'ggml-tiny.bin';
  static const _sttUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin';
  static const sttEstimatedBytes = 75 * 1024 * 1024; // ~75MB

  // ── State ──────────────────────────────────────────────────────────────────
  String? _modelsPath;
  final Map<AiModelType, AiModelStatus> _status = {
    AiModelType.llm: AiModelStatus.notDownloaded,
    AiModelType.tts: AiModelStatus.notDownloaded,
    AiModelType.stt: AiModelStatus.notDownloaded,
  };
  final Map<AiModelType, double> _progress = {
    AiModelType.llm: 0.0,
    AiModelType.tts: 0.0,
    AiModelType.stt: 0.0,
  };
  final Map<AiModelType, String> _errorMessages = {};

  bool _useAiLlm = false;
  bool _useAiTts = false;
  bool _useAiStt = false;

  bool get useAiLlm => _useAiLlm;
  bool get useAiTts => _useAiTts;
  bool get useAiStt => _useAiStt;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _useAiLlm = prefs.getBool(_prefUseAiLlm) ?? false;
    _useAiTts = prefs.getBool(_prefUseAiTts) ?? false;
    _useAiStt = prefs.getBool(_prefUseAiStt) ?? false;

    // Check which models are downloaded
    await _checkModelStatus();
    notifyListeners();
  }

  Future<void> _checkModelStatus() async {
    // Check LLM
    if (await _fileExists(_tinyLlamaFile)) {
      _status[AiModelType.llm] = AiModelStatus.ready;
    }
    
    // Check TTS - model file and tokens in extracted directory
    final dirPath = await modelsPath;
    final modelDir = Directory('$dirPath/vits-piper-en_US-lessac-medium');
    final modelFile = File('${modelDir.path}/en_US-lessac-medium.onnx');
    final tokensFile = File('${modelDir.path}/tokens.txt');
    if (modelFile.existsSync() && tokensFile.existsSync()) {
      _status[AiModelType.tts] = AiModelStatus.ready;
    }
    
    // Check STT
    if (await _fileExists(sttFileName)) {
      _status[AiModelType.stt] = AiModelStatus.ready;
    }
  }

  // ── Paths ──────────────────────────────────────────────────────────────────

  Future<String> get modelsPath async {
    if (_modelsPath != null) return _modelsPath!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_modelsDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    _modelsPath = dir.path;
    return _modelsPath!;
  }

  Future<String> _filePath(String fileName) async =>
      '${await modelsPath}/$fileName';

  Future<bool> _fileExists(String fileName) async =>
      File(await _filePath(fileName)).existsSync();

  // ── Get active LLM filename ─────────────────────────────────────────────────
  
  String get activeLlmFileName => _tinyLlamaFile;

  // ── Status queries ─────────────────────────────────────────────────────────

  AiModelStatus getStatus(AiModelType type) =>
      _status[type] ?? AiModelStatus.notDownloaded;

  double getProgress(AiModelType type) => _progress[type] ?? 0.0;

  String? getErrorMessage(AiModelType type) => _errorMessages[type];

  bool isReady(AiModelType type) => _status[type] == AiModelStatus.ready;

  /// Full path to a model file, or null if not downloaded.
  Future<String?> getModelPath(AiModelType type) async {
    if (!isReady(type)) return null;
    switch (type) {
      case AiModelType.llm:
        return _filePath(_tinyLlamaFile);
      case AiModelType.tts:
        // Piper TTS model is in extracted subdirectory
        final dirPath = await modelsPath;
        return '$dirPath/vits-piper-en_US-lessac-medium/en_US-lessac-medium.onnx';
      case AiModelType.stt:
        return _filePath(sttFileName);
    }
  }

  /// Total bytes used by all downloaded models.
  Future<int> get totalStorageUsed async {
    int total = 0;
    final path = await modelsPath;
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Get LLM info (only TinyLlama)
  AiModelInfo getLlmInfo() {
    return AiModelInfo(
      type: AiModelType.llm,
      label: 'TinyLlama 1.1B',
      description: 'Fast AI chat for mobile (~3-5s responses)',
      estimatedSize: '~600 MB',
      status: getStatus(AiModelType.llm),
      downloadProgress: getProgress(AiModelType.llm),
    );
  }

  /// Get TTS info
  AiModelInfo getTtsInfo() {
    return AiModelInfo(
      type: AiModelType.tts,
      label: 'AI Voice (TTS)',
      description: 'Piper TTS - Fast real-time voice (English, 0.2x RTF)',
      estimatedSize: '~60 MB',
      status: getStatus(AiModelType.tts),
      downloadProgress: getProgress(AiModelType.tts),
    );
  }

  /// Get STT info
  AiModelInfo getSttInfo() {
    return AiModelInfo(
      type: AiModelType.stt,
      label: 'Whisper Tiny',
      description: 'Offline voice-to-text (English/Hindi)',
      estimatedSize: '~75 MB',
      status: getStatus(AiModelType.stt),
      downloadProgress: getProgress(AiModelType.stt),
    );
  }

  // ── Toggle preferences ─────────────────────────────────────────────────────

  Future<void> setUseAiLlm(bool value) async {
    _useAiLlm = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseAiLlm, value);
    notifyListeners();
  }

  Future<void> setUseAiTts(bool value) async {
    _useAiTts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseAiTts, value);
    notifyListeners();
  }

  Future<void> setUseAiStt(bool value) async {
    _useAiStt = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefUseAiStt, value);
    notifyListeners();
  }

  // ── Download ───────────────────────────────────────────────────────────────

  /// Download LLM model (TinyLlama only)
  Future<bool> downloadLlm() async {
    if (isReady(AiModelType.llm)) return true;

    _status[AiModelType.llm] = AiModelStatus.downloading;
    _progress[AiModelType.llm] = 0.0;
    notifyListeners();

    try {
      final dest = await _filePath(_tinyLlamaFile);
      final success = await _downloadFile(
        'https://huggingface.co/$_tinyLlamaRepo/resolve/main/$_tinyLlamaFile',
        dest,
        AiModelType.llm,
        _tinyLlamaSize,
      );

      _status[AiModelType.llm] = success ? AiModelStatus.ready : AiModelStatus.error;
      _progress[AiModelType.llm] = success ? 1.0 : 0.0;

      if (success) await setUseAiLlm(true);
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('AiModelManager: LLM download error: $e');
      _status[AiModelType.llm] = AiModelStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Download TTS model (Piper - download and extract tar.bz2 archive)
  Future<bool> downloadTts() async {
    if (isReady(AiModelType.tts)) return true;

    _status[AiModelType.tts] = AiModelStatus.downloading;
    _progress[AiModelType.tts] = 0.0;
    notifyListeners();

    try {
      final dirPath = await modelsPath;
      final archiveDest = '$dirPath/$ttsArchiveFileName';
      
      // Download the tar.bz2 archive
      final success = await _downloadFile(_ttsUrl, archiveDest, AiModelType.tts, ttsEstimatedBytes);
      if (!success) {
        _status[AiModelType.tts] = AiModelStatus.error;
        notifyListeners();
        return false;
      }
      
      // Extract the archive in background isolate
      debugPrint('AiModelManager: Extracting TTS archive in background...');
      final extractDirPath = '$dirPath/vits-piper-en_US-lessac-medium';
      
      await Isolate.run(() async {
        final archiveFile = File(archiveDest);
        final bytes = await archiveFile.readAsBytes();
        final decompressed = BZip2Decoder().decodeBytes(bytes);
        final tarArchive = TarDecoder().decodeBytes(decompressed);
        
        // Extract files to models directory
        final extractDir = Directory(extractDirPath);
        if (!await extractDir.exists()) {
          await extractDir.create(recursive: true);
        }
        
        for (final file in tarArchive.files) {
          if (file.isFile) {
            final fileName = file.name;
            final filePath = '${extractDir.path}/$fileName';
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
        
        // Delete the archive after extraction
        await archiveFile.delete();
      });
      
      _status[AiModelType.tts] = AiModelStatus.ready;
      _progress[AiModelType.tts] = 1.0;

      await setUseAiTts(true);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AiModelManager: TTS download error: $e');
      _status[AiModelType.tts] = AiModelStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Download STT model
  Future<bool> downloadStt() async {
    if (isReady(AiModelType.stt)) return true;

    _status[AiModelType.stt] = AiModelStatus.downloading;
    _progress[AiModelType.stt] = 0.0;
    notifyListeners();

    try {
      final dest = await _filePath(sttFileName);
      final success = await _downloadFile(_sttUrl, dest, AiModelType.stt, sttEstimatedBytes);
      
      _status[AiModelType.stt] = success ? AiModelStatus.ready : AiModelStatus.error;
      _progress[AiModelType.stt] = success ? 1.0 : 0.0;

      if (success) await setUseAiStt(true);
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('AiModelManager: STT download error: $e');
      _status[AiModelType.stt] = AiModelStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _downloadFile(
    String url,
    String destPath,
    AiModelType type,
    int estimatedTotal,
  ) async {
    try {
      debugPrint('AiModelManager: downloading $url -> $destPath');
      _errorMessages.remove(type);

      // Use streaming request with http package (handles redirects properly)
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final msg = 'HTTP ${streamedResponse.statusCode} for $url';
        debugPrint('AiModelManager: $msg');
        _errorMessages[type] = msg;
        client.close();
        return false;
      }

      final contentLength = streamedResponse.contentLength ?? estimatedTotal;
      final file = File(destPath);
      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        _progress[type] = (downloaded / contentLength).clamp(0.0, 1.0);
        notifyListeners();
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Validate downloaded file size (at least 1MB to catch empty/error pages)
      final fileSize = await file.length();
      if (fileSize < 1024 * 1024) {
        debugPrint('AiModelManager: file too small ($fileSize bytes), likely error page');
        _errorMessages[type] = 'Download incomplete ($fileSize bytes)';
        file.deleteSync();
        return false;
      }

      debugPrint('AiModelManager: download complete, $fileSize bytes');
      return true;
    } catch (e) {
      debugPrint('AiModelManager: download error: $e');
      _errorMessages[type] = e.toString();
      final partial = File(destPath);
      if (partial.existsSync()) partial.deleteSync();
      return false;
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Delete LLM model
  Future<void> deleteLlm() async {
    await _deleteFile(_tinyLlamaFile);
    await setUseAiLlm(false);
    _status[AiModelType.llm] = AiModelStatus.notDownloaded;
    _progress[AiModelType.llm] = 0.0;
    notifyListeners();
  }

  /// Delete TTS model (Piper directory and extracted files)
  Future<void> deleteTts() async {
    final dirPath = await modelsPath;
    final modelDir = Directory('$dirPath/vits-piper-en_US-lessac-medium');
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
    final archiveFile = File('$dirPath/$ttsArchiveFileName');
    if (await archiveFile.exists()) {
      await archiveFile.delete();
    }
    await setUseAiTts(false);
    _status[AiModelType.tts] = AiModelStatus.notDownloaded;
    _progress[AiModelType.tts] = 0.0;
    notifyListeners();
  }

  /// Delete STT model
  Future<void> deleteStt() async {
    await _deleteFile(sttFileName);
    await setUseAiStt(false);
    _status[AiModelType.stt] = AiModelStatus.notDownloaded;
    _progress[AiModelType.stt] = 0.0;
    notifyListeners();
  }

  /// Delete all downloaded models.
  Future<void> deleteAll() async {
    final path = await modelsPath;
    final dir = Directory(path);
    if (await dir.exists()) await dir.delete(recursive: true);
    _modelsPath = null;

    _status[AiModelType.llm] = AiModelStatus.notDownloaded;
    _status[AiModelType.tts] = AiModelStatus.notDownloaded;
    _status[AiModelType.stt] = AiModelStatus.notDownloaded;
    _progress[AiModelType.llm] = 0.0;
    _progress[AiModelType.tts] = 0.0;
    _progress[AiModelType.stt] = 0.0;
    
    await setUseAiLlm(false);
    await setUseAiTts(false);
    await setUseAiStt(false);
    notifyListeners();
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      final file = File(await _filePath(fileName));
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('AiModelManager: delete error for $fileName: $e');
    }
  }
}
