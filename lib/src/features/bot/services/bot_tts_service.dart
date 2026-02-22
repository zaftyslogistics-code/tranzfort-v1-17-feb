import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_model_manager.dart';
import 'ai_tts_service.dart';

/// TTS service v7.0 — platform flutter_tts only.
///
/// Language routing: 'hi' → hi-IN, 'en' → en-IN.
/// Devanagari script auto-detected → hi-IN regardless of language param.
/// Hinglish (Latin-script Hindi) uses hi-IN when language == 'hi'.
/// No Piper, no just_audio, no model downloads.
class BotTtsService {
  static final BotTtsService _instance = BotTtsService._();
  factory BotTtsService() => _instance;
  BotTtsService._();

  final FlutterTts _tts = FlutterTts();
  final AiTtsService _aiTts = AiTtsService();
  bool _isInitialized = false;
  bool _isMuted = false;

  static const _mutedKey = 'bot_tts_muted';

  bool get isMuted => _isMuted;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.1);
    await _tts.setLanguage('en-IN');

    // Try to select a female Indian English voice
    try {
      final voices = await _tts.getVoices as List<dynamic>?;
      if (voices != null) {
        const femalePatterns = [
          'female', 'woman', 'aditi', 'veena', 'lekha', 'isha',
          'raveena', 'priya', 'neerja', 'swara', 'en-in-x-end',
        ];
        for (final v in voices.cast<Map<dynamic, dynamic>>()) {
          final name = (v['name']?.toString() ?? '').toLowerCase();
          final locale = (v['locale']?.toString() ?? '').toLowerCase();
          if (locale.contains('in') && femalePatterns.any((p) => name.contains(p))) {
            await _tts.setVoice({'name': v['name'].toString(), 'locale': v['locale'].toString()});
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('BotTtsService: voice selection failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool(_mutedKey) ?? false;

    _isInitialized = true;
  }

  /// Speak [text] using platform TTS.
  /// [language] — 'hi' for Hindi/Hinglish, 'en' for English.
  /// Devanagari script in text always routes to hi-IN regardless of [language].
  Future<void> speak(String text, String language) async {
    if (_isMuted || text.isEmpty) return;
    await initialize();

    final cleanText = _cleanForTts(text);
    if (cleanText.isEmpty) return;

    final useHindi = language == 'hi' || _containsDevanagari(cleanText);
    final targetLang = useHindi ? 'hi' : 'en';

    // Auto-switch to AI TTS when model is ready and user enabled it.
    final modelMgr = AiModelManager();
    final canUseAiTts = modelMgr.useAiTts && modelMgr.isReady(AiModelType.tts);
    if (canUseAiTts) {
      final aiReady = await _aiTts.initialize();
      if (aiReady) {
        await _aiTts.speak(cleanText, targetLang);
        return;
      }
      debugPrint('BotTtsService: AI TTS init failed, falling back to platform TTS');
    }

    await _tts.setLanguage(useHindi ? 'hi-IN' : 'en-IN');
    await _tts.speak(cleanText);
  }

  /// Strip emoji, arrows, bullets — keep Latin, Devanagari, punctuation.
  String _cleanForTts(String text) {
    return text
        .replaceAll(RegExp(r'[^\x00-\x7F\u0900-\u097F\s\d.,!?%/\-]'), '')
        .replaceAll('→', ' se ')
        .replaceAll('•', ', ')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  bool _containsDevanagari(String text) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(text);

  Future<void> stop() async {
    await _aiTts.stop();
    await _tts.stop();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) await stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedKey, _isMuted);
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    if (_isMuted) await stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mutedKey, _isMuted);
  }
}
