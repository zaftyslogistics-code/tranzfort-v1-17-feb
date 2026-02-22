import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_service_provider.dart';
import '../services/basic_bot_service.dart';
import '../services/ai_model_manager.dart';
import '../services/llm_service.dart';
import '../services/ai_tts_service.dart';
import '../services/ai_stt_service.dart';

final botServiceProvider = Provider<BasicBotService>((ref) {
  final bot = BasicBotService();
  // P2-3/P2-4: Inject DB service for data queries (truck loads, load status)
  bot.setDatabaseService(ref.read(databaseServiceProvider));
  return bot;
});

/// Singleton AiModelManager — manages download/delete/status of all AI models.
final aiModelManagerProvider = ChangeNotifierProvider<AiModelManager>((ref) {
  final mgr = AiModelManager();
  mgr.initialize();
  return mgr;
});

/// On-device LLM service (Qwen2.5-0.5B via llm_llamacpp).
final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService();
});

/// On-device AI TTS (Kokoro-82M).
final aiTtsServiceProvider = Provider<AiTtsService>((ref) {
  final svc = AiTtsService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// On-device AI STT (Whisper Tiny).
final aiSttServiceProvider = Provider<AiSttService>((ref) {
  final svc = AiSttService();
  ref.onDispose(() => svc.dispose());
  return svc;
});
