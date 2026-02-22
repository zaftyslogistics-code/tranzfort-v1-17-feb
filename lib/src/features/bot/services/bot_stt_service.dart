import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// STT service v6.0 — platform SpeechRecognizer via speech_to_text.
///
/// Tap-to-toggle UX: one tap starts, next tap stops.
/// No press-and-hold, no race conditions, no custom booleans.
/// Language hint: hi_IN for Hindi/Hinglish, en_IN for English.
///
/// API:
///   [initialize]              — request mic permission, init plugin.
///   [isAvailable]             — true if STT is available on device.
///   [isListening]             — true while actively listening.
///   [start(language, onResult, onDone)] — begin listening.
///   [stop]                    — stop listening (triggers final result).
///   [cancel]                  — cancel without result.
class BotSttService {
  static final BotSttService _instance = BotSttService._internal();
  factory BotSttService() => _instance;
  BotSttService._internal();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  /// True if STT is available and mic permission granted.
  bool get isAvailable => _stt.isAvailable;

  /// True while actively listening.
  bool get isListening => _stt.isListening;

  // ── Initialize ──────────────────────────────────────────────────────────────

  Future<bool> initialize() async {
    if (_initialized) return _stt.isAvailable;
    try {
      _initialized = await _stt.initialize(
        onError: (e) => debugPrint('BotSttService error: ${e.errorMsg}'),
        onStatus: (_) {}, // no-op — tap-to-toggle handles state
      );
    } catch (e) {
      debugPrint('BotSttService.initialize error: $e');
      _initialized = false;
    }
    return _initialized;
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  /// Start listening.
  /// [language] — 'hi' for Hindi/Hinglish (hi_IN), 'en' for English (en_IN).
  /// [onResult]  — called with partial and final results.
  /// [onDone]    — called when engine stops (final result ready).
  Future<void> start({
    required String language,
    required void Function(String text, bool isFinal) onResult,
    void Function()? onDone,
  }) async {
    if (!_initialized) await initialize();
    if (!_stt.isAvailable) return;

    final localeId = language == 'hi' ? 'hi_IN' : 'en_IN';

    await _stt.listen(
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
      ),
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) onDone?.call();
      },
    );
  }

  /// Stop listening — triggers final result callback.
  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
  }

  /// Cancel without triggering result.
  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
  }
}
