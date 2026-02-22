import 'package:flutter_tts/flutter_tts.dart';
import '../../features/bot/services/ai_model_manager.dart';
import '../../features/bot/services/ai_tts_service.dart';

/// TTS service used by TtsButton on load cards and detail screens.
/// Platform flutter_tts only — no Piper, no model downloads.
/// Pass [locale] to route language correctly (hi-IN for Hindi/Hinglish).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AiTtsService _aiTts = AiTtsService();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init({String locale = 'en-IN'}) async {
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
  }

  /// Speak [text] in the given [locale].
  /// [locale] — 'hi-IN' for Hindi/Hinglish, 'en-IN' for English.
  /// Devanagari script auto-routes to hi-IN regardless of [locale].
  Future<void> speak(String text, {String locale = 'en-IN'}) async {
    if (text.isEmpty) return;

    final cleanText = _cleanForTts(text);
    if (cleanText.isEmpty) return;

    _isSpeaking = true;
    final useHindi = locale.startsWith('hi') || _containsDevanagari(cleanText);

    // Auto-switch to AI TTS when model is ready and user enabled it.
    final modelMgr = AiModelManager();
    final canUseAiTts = modelMgr.useAiTts && modelMgr.isReady(AiModelType.tts);
    if (canUseAiTts) {
      final aiReady = await _aiTts.initialize();
      if (aiReady) {
        await _aiTts.speak(cleanText, useHindi ? 'hi' : 'en');
        _isSpeaking = false;
        return;
      }
    }

    await _tts.setLanguage(useHindi ? 'hi-IN' : 'en-IN');
    await _tts.speak(cleanText);
  }

  String _cleanForTts(String text) {
    return text
        .replaceAll(RegExp(r'[^\x00-\x7F\u0900-\u097F\s\d.,!?%/\-]'), '')
        .replaceAll('→', ' to ')
        .replaceAll('•', ', ')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  bool _containsDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

  Future<void> stop() async {
    _isSpeaking = false;
    await _aiTts.stop();
    await _tts.stop();
  }

  Future<void> dispose() async => _tts.stop();
}
