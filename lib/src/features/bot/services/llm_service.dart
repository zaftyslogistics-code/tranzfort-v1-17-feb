import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fllama/fllama.dart';
import 'ai_model_manager.dart';

/// Timing metrics for LLM performance analysis
class LlmTimingMetrics {
  final int ttfbMs; // Time to first token
  final int totalMs; // Total generation time
  final int tokenCount;
  final double tokensPerSecond;
  final DateTime timestamp;

  LlmTimingMetrics({
    required this.ttfbMs,
    required this.totalMs,
    required this.tokenCount,
    required this.tokensPerSecond,
  }) : timestamp = DateTime.now();

  @override
  String toString() =>
      'TTFB: ${ttfbMs}ms, Total: ${totalMs}ms, Tokens: $tokenCount, TPS: ${tokensPerSecond.toStringAsFixed(1)}';
}

/// On-device LLM service using fllama (alternative to llm_llamacpp).
/// Uses llama.cpp under the hood but with better Android support.
class LlmService {
  static final LlmService _instance = LlmService._();
  factory LlmService() => _instance;
  LlmService._();

  bool _isLoaded = false;
  String? _loadedModelPath;
  LlmTimingMetrics? _lastMetrics;
  final List<Message> _conversationHistory = [];

  static const _contextSize = 2048;
  static const _maxTokens = 256;

  bool get isLoaded => _isLoaded;
  LlmTimingMetrics? get lastMetrics => _lastMetrics;

  /// True if the LLM model file exists and user has opted in.
  Future<bool> get isReady async {
    final mgr = AiModelManager();
    return mgr.isReady(AiModelType.llm) && mgr.useAiLlm;
  }

  /// Load the model into memory. No-op if already loaded.
  Future<bool> load() async {
    if (_isLoaded) {
      return true;
    }

    final mgr = AiModelManager();
    final modelPath = await mgr.getModelPath(AiModelType.llm);
    if (modelPath == null) {
      debugPrint('LlmService: model path not found');
      return false;
    }

    try {
      // Verify file exists and has reasonable size
      final file = File(modelPath);
      if (!file.existsSync()) {
        debugPrint('LlmService: model file not found at $modelPath');
        return false;
      }
      final fileSize = file.lengthSync();
      debugPrint('LlmService: model file size=${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB');
      if (fileSize < 10 * 1024 * 1024) {
        debugPrint('LlmService: model file too small, likely corrupted');
        return false;
      }

      _loadedModelPath = modelPath;
      _isLoaded = true;
      debugPrint('LlmService: model ready at $modelPath');
      return true;
    } catch (e, stack) {
      debugPrint('LlmService: load error: $e');
      debugPrint('LlmService: stack: $stack');
      _isLoaded = false;
      _loadedModelPath = null;
      return false;
    }
  }

  /// Unload model from memory.
  void unload() {
    _isLoaded = false;
    _loadedModelPath = null;
    _conversationHistory.clear();
    debugPrint('LlmService: model unloaded');
  }

  /// Generate a streaming response using fllama.
  /// Returns a Stream of token strings. Caller concatenates them.
  Stream<String> streamResponse({
    required String userMessage,
    String? userRole,
    String language = 'en',
    List<Map<String, String>>? conversationHistory,
  }) async* {
    if (!_isLoaded) {
      final ok = await load();
      if (!ok) {
        yield language == 'hi'
            ? 'AI model load nahi ho paya. Rule-based bot use ho raha hai.'
            : 'AI model could not load. Using basic bot.';
        return;
      }
    }

    final stopwatch = Stopwatch()..start();
    DateTime? firstTokenTime;
    int tokenCount = 0;
    final buffer = StringBuffer();

    // Build messages
    final messages = <Message>[
      Message(Role.system, _buildSystemPrompt(userRole, language)),
    ];

    // Add conversation history
    if (conversationHistory != null) {
      for (final msg in conversationHistory) {
        final role = msg['role'] == 'user' ? Role.user : Role.assistant;
        messages.add(Message(role, msg['content'] ?? ''));
      }
    }

    messages.add(Message(Role.user, userMessage));

    final request = OpenAiRequest(
      maxTokens: _maxTokens,
      messages: messages,
      numGpuLayers: 0, // CPU-only for mobile compatibility
      modelPath: _loadedModelPath!,
      frequencyPenalty: 0.0,
      presencePenalty: 1.1, // Prevent repetition
      topP: 1.0,
      contextSize: _contextSize,
      temperature: 0.7, // Slightly creative but consistent
      logger: (log) {
        debugPrint('[fllama] $log');
      },
    );

    final completer = Completer<void>();
    
    fllamaChat(request, (response, token, done) {
      if (firstTokenTime == null && response.isNotEmpty) {
        firstTokenTime = DateTime.now();
        debugPrint('LlmService: TTFB = ${stopwatch.elapsedMilliseconds}ms');
      }
      
      if (response.length > buffer.length) {
        final newText = response.substring(buffer.length);
        tokenCount += newText.length ~/ 4; // Rough estimate: ~4 chars per token
        buffer.write(newText);
      }
      
      if (done) {
        stopwatch.stop();
        final totalMs = stopwatch.elapsedMilliseconds;
        final ttfbMs = firstTokenTime != null
            ? firstTokenTime!.difference(DateTime.now().subtract(Duration(milliseconds: totalMs))).inMilliseconds
            : totalMs;
        final tps = totalMs > 0 ? tokenCount / (totalMs / 1000) : 0.0;

        _lastMetrics = LlmTimingMetrics(
          ttfbMs: ttfbMs,
          totalMs: totalMs,
          tokenCount: tokenCount,
          tokensPerSecond: tps,
        );
        debugPrint('LlmService: $_lastMetrics');
        
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Stream the response as it comes in
    var lastLength = 0;
    while (!completer.isCompleted) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (buffer.length > lastLength) {
        final newText = buffer.toString().substring(lastLength);
        lastLength = buffer.length;
        yield newText;
      }
    }
    
    // Yield any remaining text
    if (buffer.length > lastLength) {
      yield buffer.toString().substring(lastLength);
    }
  }

  /// Generate a complete (non-streaming) response.
  Future<String> generateResponse({
    required String userMessage,
    String? userRole,
    String language = 'en',
    List<Map<String, String>>? conversationHistory,
  }) async {
    final buffer = StringBuffer();
    await for (final token in streamResponse(
      userMessage: userMessage,
      userRole: userRole,
      language: language,
      conversationHistory: conversationHistory,
    )) {
      buffer.write(token);
    }
    return buffer.toString();
  }

  String _buildSystemPrompt(String? userRole, String language) {
    final roleContext = userRole == 'supplier'
        ? 'The user is a Supplier who posts loads for truckers to transport.'
        : userRole == 'trucker'
            ? 'The user is a Trucker who finds and transports loads.'
            : 'The user role is unknown.';

    final langInstruction = language == 'hi'
        ? 'Respond in simple English or Hinglish. Keep responses very short and conversational.'
        : 'Respond in simple English. Keep responses very short and conversational.';

    // TinyLlama uses simpler prompt format than Qwen
    return '''You are Nancy, an AI assistant for TranZfort trucking logistics in India.
$roleContext
$langInstruction

Help with: posting loads, finding loads, navigation, and answering questions.

Guidelines:
- Be extremely concise (1-2 sentences max)
- No emojis (will be spoken by TTS)
- Don't make up data
- Ask for missing details when needed''';
  }
}
