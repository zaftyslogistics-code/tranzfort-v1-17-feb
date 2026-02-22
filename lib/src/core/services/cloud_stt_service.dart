import 'dart:developer' as dev;
import 'dart:io';

/// REL-4: Cloud STT alternative service.
/// Falls back to cloud-based speech-to-text when on-device Whisper
/// is unavailable or too slow. Supports Google Cloud Speech-to-Text
/// or Deepgram as backends.
class CloudSttService {
  static final CloudSttService _instance = CloudSttService._internal();
  factory CloudSttService() => _instance;
  CloudSttService._internal();

  /// Whether cloud STT is configured and available.
  bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;

  String? _apiKey;
  String _provider = 'deepgram'; // 'deepgram' or 'google'
  String _language = 'hi'; // Default Hindi

  /// Initialize with API key. Call from settings or env config.
  void configure({
    required String apiKey,
    String provider = 'deepgram',
    String language = 'hi',
  }) {
    _apiKey = apiKey;
    _provider = provider;
    _language = language;
    dev.log('[CloudSTT] Configured: provider=$_provider, lang=$_language');
  }

  /// Transcribe audio file to text using cloud STT.
  /// Returns transcribed text or null on failure.
  Future<String?> transcribe(File audioFile) async {
    if (!isAvailable) {
      dev.log('[CloudSTT] Not configured — falling back to on-device');
      return null;
    }

    dev.log('[CloudSTT] Transcribing ${audioFile.path} via $_provider');

    try {
      // TODO: Implement actual API calls
      // For Deepgram:
      //   POST https://api.deepgram.com/v1/listen?language=$_language
      //   Headers: Authorization: Token $_apiKey
      //   Body: audio file bytes
      //
      // For Google Cloud Speech-to-Text:
      //   POST https://speech.googleapis.com/v1/speech:recognize
      //   Headers: Authorization: Bearer $_apiKey
      //   Body: { config: { languageCode: $_language }, audio: { content: base64 } }

      dev.log('[CloudSTT] Placeholder — returning null');
      return null;
    } catch (e) {
      dev.log('[CloudSTT] Error: $e');
      return null;
    }
  }

  /// Transcribe from audio bytes (for streaming use).
  Future<String?> transcribeBytes(List<int> audioBytes) async {
    if (!isAvailable) return null;

    dev.log('[CloudSTT] Transcribing ${audioBytes.length} bytes via $_provider');
    // TODO: Implement streaming transcription
    return null;
  }
}
