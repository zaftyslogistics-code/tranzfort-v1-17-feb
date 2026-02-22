import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/load_constants.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../models/bot_intent.dart';
import '../../models/bot_response.dart';
import '../../providers/bot_provider.dart';
import '../../services/bot_tts_service.dart';
import '../../services/bot_stt_service.dart';
import '../../services/ai_model_manager.dart';
import '../../services/ai_stt_service.dart';

class BotChatScreen extends ConsumerStatefulWidget {
  const BotChatScreen({super.key});

  @override
  ConsumerState<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends ConsumerState<BotChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _tts = BotTtsService();
  final _stt = BotSttService();
  final _aiStt = AiSttService();
  final List<BotMessage> _messages = [];
  bool _showAiCta = true;
  bool _ttsMuted = false;
  bool _isProcessing = false;
  bool _isTranscribing = false;
  String? _userRole;
  String _partialTranscript = '';
  String _streamingText = '';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _tts.initialize();
    if (mounted) setState(() => _ttsMuted = _tts.isMuted);

    // Load user role
    _userRole = await ref.read(userRoleProvider.future);

    // Initialize STT (requests mic permission internally)
    await _stt.initialize();
    if (mounted) setState(() {}); // Rebuild to show/hide mic button


    await ref.read(botServiceProvider).initialize();
    if (!mounted) return;
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId != null) {
      // P2-5: Restore persisted conversation if available
      await ref.read(botServiceProvider).restoreConversation(userId);
      final state = ref.read(botServiceProvider).getConversationHistory(userId);
      if (state != null && state.isNotEmpty) {
        setState(() => _messages.addAll(state));
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return;
      }
    }
    _addBotGreeting();
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.cancel();
    _controller.dispose();
    _scrollController.dispose();
    // F-21: Auto-save draft when leaving mid-flow so user can resume later
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId != null) {
      final bot = ref.read(botServiceProvider);
      final activeIntent = bot.getActiveIntent(userId);
      if (activeIntent != null) {
        bot.saveConversation(userId);
      }
    }
    super.dispose();
  }

  // ── Tap-to-toggle mic (v6.0 — platform STT) ─────────────────────────────
  //
  // Tap 1 → start listening (platform SpeechRecognizer, hi_IN or en_IN).
  // Tap 2 → stop listening → final result → send.
  // No Whisper, no recording files, no race conditions.

  Future<void> _toggleMic() async {
    if (_isProcessing) return;

    // Check if AI STT (Whisper) is available and preferred
    final mgr = ref.read(aiModelManagerProvider);
    final useWhisper = mgr.useAiStt && mgr.isReady(AiModelType.stt);

    if (useWhisper) {
      await _toggleWhisperMic();
      return;
    }

    // Fallback: platform STT
    if (_stt.isListening) {
      // Capture partial transcript before stopping — stop() doesn't always
      // fire a final result callback on all Android devices.
      final pending = _partialTranscript;
      await _stt.stop();
      if (mounted) {
        setState(() => _partialTranscript = '');
        if (pending.isNotEmpty) {
          _sendMessage(pending);
        }
      }
      return;
    }

    if (!_stt.isAvailable) {
      final ok = await _stt.initialize();
      if (!ok) {
        _showMicUnavailableHint();
        return;
      }
    }

    await _tts.stop();
    _controller.clear();
    _partialTranscript = '';

    final lang = ref.read(localeProvider).languageCode;
    await _stt.start(
      language: lang,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _partialTranscript = text);
        if (isFinal && text.isNotEmpty) {
          _partialTranscript = '';
          _sendMessage(text);
        }
      },
      onDone: () {
        if (mounted) setState(() => _partialTranscript = '');
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleWhisperMic() async {
    if (_aiStt.isRecording) {
      // Stop and transcribe — show transcribing state
      setState(() {
        _isTranscribing = true;
        _partialTranscript = '';
      });
      final lang = ref.read(localeProvider).languageCode;
      final text = await _aiStt.stopAndTranscribe(language: lang);
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _partialTranscript = '';
        });
        if (text != null && text.isNotEmpty) {
          _sendMessage(text);
        }
      }
      return;
    }

    // Initialize if needed
    if (!_aiStt.isInitialized) {
      final ok = await _aiStt.initialize();
      if (!ok) {
        _showMicUnavailableHint();
        return;
      }
    }

    await _tts.stop();
    _controller.clear();
    _partialTranscript = '';

    final ok = await _aiStt.startRecording();
    if (!ok) {
      _showMicUnavailableHint();
      return;
    }
    if (mounted) setState(() => _partialTranscript = 'Listening (Whisper)...');
  }

  void _showMicUnavailableHint() {
    if (!mounted) return;
    final isHi = ref.read(localeProvider).languageCode == 'hi';
    final text = isHi
        ? 'माइक अनुमति दें और फिर से प्रयास करें।'
        : 'Please allow microphone permission and try again.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _addSystemBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(BotMessage(text: text, isUser: false));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _handleBotAction(BotAction action) async {
    final payload = action.payload ?? const <String, dynamic>{};
    final actionType = payload['action']?.toString();

    try {
      switch (actionType) {
        case 'post_load':
          await _executePostLoadAction(payload);
          break;
        case 'find_loads':
          await _executeFindLoadsAction(payload);
          break;
        default:
          _addSystemBotMessage('Unsupported bot action: $actionType');
      }
    } catch (e) {
      final isHi = ref.read(localeProvider).languageCode == 'hi';
      _addSystemBotMessage(
        isHi
            ? 'एक समस्या आई। कृपया दोबारा प्रयास करें।'
            : 'Something went wrong while executing your request.',
      );
    }
  }

  Future<String> _resolveStateForCity(String city) async {
    final citySearch = ref.read(citySearchServiceProvider);
    final matches = await citySearch.search(city, limit: 8);
    final normalized = city.trim().toLowerCase();

    for (final match in matches) {
      if (match.name.toLowerCase() == normalized) {
        return match.state;
      }
    }
    if (matches.isNotEmpty) {
      return matches.first.state;
    }
    return 'Unknown';
  }

  Future<void> _executePostLoadAction(Map<String, dynamic> payload) async {
    final isHi = ref.read(localeProvider).languageCode == 'hi';
    final auth = ref.read(authServiceProvider);
    final db = ref.read(databaseServiceProvider);
    final user = auth.currentUser;

    if (user == null) {
      _addSystemBotMessage(
        isHi ? 'पहले लॉगिन करें।' : 'Please log in first.',
      );
      return;
    }
    if (_userRole != 'supplier') {
      _addSystemBotMessage(
        isHi
            ? 'लोड पोस्ट करने के लिए Supplier रोल चाहिए।'
            : 'Post Load is available for Supplier role only.',
      );
      return;
    }

    final origin = (payload['origin']?.toString() ?? '').trim();
    final destination = (payload['destination']?.toString() ?? '').trim();
    final materialRaw = (payload['material']?.toString() ?? '').trim();
    // LP-5: Validate material against LoadConstants
    final material = LoadConstants.materials
            .firstWhere(
              (m) => m.toLowerCase() == materialRaw.toLowerCase(),
              orElse: () => '',
            )
            .isNotEmpty
        ? LoadConstants.materials.firstWhere(
            (m) => m.toLowerCase() == materialRaw.toLowerCase())
        : materialRaw.isNotEmpty
            ? 'Other'
            : '';
    final truckTypeRaw = (payload['truck_type']?.toString() ?? '').trim();
    final truckType = (truckTypeRaw.isEmpty || truckTypeRaw.toLowerCase() == 'any')
        ? null
        : truckTypeRaw.toLowerCase();
    final weightRaw = (payload['weight']?.toString() ?? '').trim();
    final weight = double.tryParse(weightRaw);
    final priceRaw = (payload['price']?.toString() ?? '').trim();
    final parsedPrice = double.tryParse(priceRaw);
    final price = (parsedPrice == null || parsedPrice <= 0) ? null : parsedPrice;
    final pickupDateRaw = (payload['pickup_date']?.toString() ?? '').trim();
    final pickupDate = pickupDateRaw.isNotEmpty
        ? pickupDateRaw
        : DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first;

    if (origin.isEmpty ||
        destination.isEmpty ||
        material.isEmpty ||
        weight == null ||
        weight <= 0 ||
        price == null) {
      _addSystemBotMessage(
        isHi
            ? 'लोड पोस्ट करने के लिए कुछ जानकारी अधूरी है। फिर से प्रयास करें।'
            : 'Some required load details are missing. Please try again.',
      );
      return;
    }

    final profile = await db.getUserProfile(user.id);
    final verificationStatus =
        profile?['verification_status'] as String? ?? 'unverified';
    if (verificationStatus != 'verified') {
      _addSystemBotMessage(
        isHi
            ? 'लोड पोस्ट करने से पहले वेरिफिकेशन पूरा करें।'
            : 'Please complete verification before posting loads.',
      );
      if (mounted) context.push('/supplier-verification');
      return;
    }

    final originState = await _resolveStateForCity(origin);
    final destState = await _resolveStateForCity(destination);

    await db.createLoad({
      'supplier_id': user.id,
      'origin_city': origin,
      'origin_state': originState,
      'dest_city': destination,
      'dest_state': destState,
      'material': material,
      'weight_tonnes': weight,
      'required_truck_type': truckType,
      'required_tyres': (payload['tyres']?.toString().toLowerCase() == 'any')
          ? null
          : int.tryParse(payload['tyres']?.toString() ?? ''),
      'price': price,
      'price_type': payload['price_type']?.toString() ?? 'negotiable',
      'advance_percentage':
          int.tryParse(payload['advance_percentage']?.toString() ?? '') ?? 80,
      'pickup_date': pickupDate,
      'status': 'active',
    });

    await SmartDefaults.saveLastRoute(origin, destination);
    ref.invalidate(supplierActiveLoadsCountProvider);
    ref.invalidate(supplierRecentLoadsProvider);

    _addSystemBotMessage(
      isHi
          ? '✅ लोड सफलतापूर्वक पोस्ट हो गया। My Loads स्क्रीन खोल रहा हूँ...'
          : '✅ Load posted successfully. Opening My Loads...',
    );
    if (mounted) context.push('/my-loads');
  }

  Future<void> _executeFindLoadsAction(Map<String, dynamic> payload) async {
    final isHi = ref.read(localeProvider).languageCode == 'hi';
    final db = ref.read(databaseServiceProvider);

    final origin = (payload['origin']?.toString() ?? '').trim();
    final destination = (payload['destination']?.toString() ?? '').trim();

    final results = await db.getActiveLoads(
      originCity: origin.isEmpty ? null : origin,
      destCity: destination.isEmpty ? null : destination,
    );

    if (results.isEmpty) {
      _addSystemBotMessage(
        isHi
            ? 'इस रूट पर अभी कोई active load नहीं मिला।'
            : 'No active loads found for this route right now.',
      );
      return;
    }

    final preview = results.take(3).map((load) {
      final route = '${load['origin_city']} → ${load['dest_city']}';
      final material = load['material']?.toString() ?? '-';
      final weight = load['weight_tonnes']?.toString() ?? '-';
      final price = load['price']?.toString() ?? '-';
      return '• $route | $material | ${weight}T | ₹$price';
    }).join('\n');

    _addSystemBotMessage(
      isHi
          ? '🔎 ${results.length} लोड मिले:\n$preview\n\nFind Loads स्क्रीन खोल रहा हूँ...'
          : '🔎 Found ${results.length} loads:\n$preview\n\nOpening Find Loads...',
    );

    await SmartDefaults.saveLastSearch(origin, destination);
    if (mounted) {
      final targetRoute = _userRole == 'trucker'
          ? '/find-loads'
          : '/supplier-dashboard';
      if (_userRole == 'trucker') {
        context.push(targetRoute, extra: {
          'origin': origin,
          'destination': destination,
          'autoSearch': true,
        });
      } else {
        context.push(targetRoute);
      }
    }
  }

  List<String> _getRoleSuggestions(String lang) {
    if (lang == 'hi') {
      if (_userRole == 'supplier') {
        return ['लोड भेजना है', 'मदद', 'वेरिफिकेशन', 'कीमत'];
      } else if (_userRole == 'trucker') {
        return ['लोड खोजें', 'मदद', 'वेरिफिकेशन', 'कीमत'];
      }
      return ['लोड भेजना है', 'लोड खोजें', 'मदद', 'वेरिफिकेशन'];
    }
    if (_userRole == 'supplier') {
      return ['Post a Load', 'Help', 'Verification', 'Pricing'];
    } else if (_userRole == 'trucker') {
      return ['Find Loads', 'Help', 'Verification', 'Pricing'];
    }
    return ['Post a Load', 'Find Loads', 'Help', 'Verification'];
  }

  Future<void> _addBotGreeting() async {
    final locale = ref.read(localeProvider);
    final lang = locale.languageCode;
    final suggestions = _getRoleSuggestions(lang);

    // Fetch user context in parallel for context-aware greeting
    final auth = ref.read(authServiceProvider);
    final db = ref.read(databaseServiceProvider);
    final user = auth.currentUser;

    int activeLoads = 0;
    int activeTrips = 0;
    String? verificationStatus;

    if (user != null) {
      try {
        final results = await Future.wait([
          _userRole == 'supplier'
              ? db.getMyLoads(user.id).then((loads) =>
                  loads.where((l) => l['status'] == 'active').length)
              : Future.value(0),
          _userRole == 'trucker'
              ? db.getMyTrips(user.id).then((trips) =>
                  trips.where((t) => t['status'] != 'completed').length)
              : Future.value(0),
          db.getUserProfile(user.id).then((p) =>
              p?['verification_status'] as String? ?? 'unverified'),
        ]);
        activeLoads = results[0] as int;
        activeTrips = results[1] as int;
        verificationStatus = results[2] as String;
      } catch (_) {
        // Silently fall back to basic greeting
      }
    }

    if (!mounted) return;

    final greeting = ref.read(botServiceProvider).getContextGreeting(
      language: lang,
      userRole: _userRole,
      activeLoadsCount: activeLoads,
      activeTripsCount: activeTrips,
      verificationStatus: verificationStatus,
    );

    final greetingMsg = BotMessage(
      text: greeting,
      isUser: false,
      suggestions: suggestions,
    );

    setState(() {
      _messages.add(greetingMsg);
    });

    // Persist greeting as first message in conversation
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId != null) {
      final bot = ref.read(botServiceProvider);
      bot.addMessageToHistory(userId, greetingMsg);
      bot.saveConversation(userId);
    }

    // TTS greeting — use ttsText to strip emoji/symbols
    _tts.speak(greetingMsg.ttsText, lang);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    final trimmed = text.trim();

    // Add user message immediately — synchronous setState before any await
    setState(() {
      _isProcessing = true;
      _messages.add(BotMessage(text: trimmed, isUser: true));
    });
    // Scroll after frame so the new message is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final locale = ref.read(localeProvider);
    final lang = locale.languageCode;
    final userId =
        ref.read(authServiceProvider).currentUser?.id ?? 'anonymous';
    final l10n = AppLocalizations.of(context);

    // Architecture: ALWAYS route through rule-bot first.
    // Qwen LLM is only used as a conversational fallback when the rule-bot
    // returns a 'fallback' intent (i.e., it couldn't understand the message).
    // This preserves all structured capabilities: post load, find loads,
    // slot-filling, DB actions, navigation, etc.
    await _sendWithRuleBot(trimmed, lang, userId, l10n);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendWithRuleBot(
      String trimmed, String lang, String userId, AppLocalizations? l10n) async {
    bool handedOffToLlm = false;
    try {
      final response = await ref.read(botServiceProvider).processMessage(
            userId: userId,
            message: trimmed,
            language: lang,
            userRole: _userRole,
            l10n: l10n,
          );

      if (!mounted) return;

      // If rule-bot returned a fallback AND Qwen LLM is available,
      // use Qwen to generate a better conversational response.
      final mgr = ref.read(aiModelManagerProvider);
      final llmAvailable = mgr.useAiLlm && mgr.isReady(AiModelType.llm);
      if (response.intentType == 'fallback' && llmAvailable) {
        handedOffToLlm = true;
        await _sendWithLlm(trimmed, lang, userId);
        return; // _sendWithLlm handles _isProcessing in its own finally
      }

      setState(() {
        _messages.add(BotMessage(
          text: response.text,
          isUser: false,
          suggestions: response.suggestions,
          actions: response.actions,
          inputType: response.inputType,
        ));
      });

      ref.read(botServiceProvider).saveConversation(userId);
      _speakResponse(response.ttsText, lang);

      if (response.action?.value == 'execute') {
        await _handleBotAction(response.action!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(BotMessage(
          text: AppLocalizations.of(context)?.error ?? 'Something went wrong',
          isUser: false,
        ));
      });
    } finally {
      // Don't reset _isProcessing if we handed off to LLM — it manages its own state
      if (!handedOffToLlm && mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _sendWithLlm(String trimmed, String lang, String userId) async {
    // Add a placeholder bot message for streaming
    final streamIdx = _messages.length;
    setState(() {
      _streamingText = '';
      _messages.add(BotMessage(text: '', isUser: false));
    });

    try {
      final llm = ref.read(llmServiceProvider);

      // Build conversation history from recent messages (last 10)
      final history = <Map<String, String>>[];
      final recentMsgs = _messages.length > 12
          ? _messages.sublist(_messages.length - 12, _messages.length - 1)
          : _messages.sublist(0, _messages.length - 1);
      for (final msg in recentMsgs) {
        if (msg.text.isNotEmpty) {
          history.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
      }

      final buffer = StringBuffer();
      await for (final token in llm.streamResponse(
        userMessage: trimmed,
        userRole: _userRole,
        language: lang,
        conversationHistory: history,
      )) {
        buffer.write(token);
        if (mounted) {
          setState(() {
            _streamingText = buffer.toString();
            if (streamIdx < _messages.length) {
              _messages[streamIdx] = BotMessage(
                text: _streamingText,
                isUser: false,
              );
            }
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      }

      final finalText = buffer.toString().trim();
      if (mounted && finalText.isNotEmpty) {
        setState(() {
          if (streamIdx < _messages.length) {
            _messages[streamIdx] = BotMessage(
              text: finalText,
              isUser: false,
            );
          }
        });
        _speakResponse(finalText, lang);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (streamIdx < _messages.length) {
          _messages[streamIdx] = BotMessage(
            text: lang == 'hi'
                ? 'AI mein error aaya. Dobara try karein.'
                : 'AI error occurred. Please try again.',
            isUser: false,
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _streamingText = '';
        });
      }
    }
  }

  /// Speak using AI TTS if available, else platform TTS.
  void _speakResponse(String text, String lang) {
    // Always use platform TTS (Kokoro removed)
    _tts.speak(text, lang);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleTts() {
    _tts.toggleMute();
    setState(() => _ttsMuted = _tts.isMuted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/bot-avatar.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.botTitle,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          // New conversation
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.mediumImpact();
              final userId = ref.read(authServiceProvider).currentUser?.id;
              if (userId != null) {
                ref.read(botServiceProvider).resetConversation(userId);
              }
              setState(() => _messages.clear());
              _addBotGreeting();
            },
            tooltip: 'New conversation',
          ),
          // TTS mute/unmute toggle
          IconButton(
            icon: Icon(
              _ttsMuted ? Icons.volume_off : Icons.volume_up,
              color: _ttsMuted ? AppColors.textTertiary : AppColors.brandTeal,
            ),
            onPressed: _toggleTts,
            tooltip: _ttsMuted ? 'Unmute voice' : 'Mute voice',
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Download CTA banner
          if (_showAiCta) _buildAiCtaBanner(l10n),
          // D2: post_load progress indicator
          _buildProgressIndicator(),
          // F-07: Pinned smart input area (chips + smart widgets for last bot message)
          _buildPinnedInputArea(),
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
                vertical: 12,
              ),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator as last item
                if (index == _messages.length && _isProcessing) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                // A9-FIX: Only show action buttons on the last bot message
                final isLastBotMsg = !msg.isUser &&
                    index == _messages.lastIndexWhere((m) => !m.isUser);
                return _buildMessageBubble(msg, showActions: isLastBotMsg);
              },
            ),
          ),
          // Input bar
          _buildInputBar(l10n),
        ],
      ),
    );
  }

  Widget _buildAiCtaBanner(AppLocalizations l10n) {
    final mgr = ref.watch(aiModelManagerProvider);
    final llmStatus = mgr.getStatus(AiModelType.llm);
    final isDownloading = llmStatus == AiModelStatus.downloading;
    final isReady = llmStatus == AiModelStatus.ready;
    final progress = mgr.getProgress(AiModelType.llm);

    // Don't show banner if LLM is ready and enabled
    if (isReady && mgr.useAiLlm) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReady ? 'AI Bot Ready' : 'Upgrade to AI Bot',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isDownloading
                          ? 'Downloading AI model...'
                          : isReady
                              ? 'Enable AI for smarter responses'
                              : 'Download for smarter, AI-powered responses (~400 MB)',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDownloading && !isReady)
                GestureDetector(
                  onTap: () => mgr.downloadLlm(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Download',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (isReady && !mgr.useAiLlm)
                GestureDetector(
                  onTap: () => mgr.setUseAiLlm(true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Enable',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _showAiCta = false),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 600 + i * 200),
                builder: (context, value, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary
                          .withValues(alpha: 0.4 + 0.6 * ((value + i * 0.33) % 1.0)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BotMessage msg, {bool showActions = true}) {
    final timeStr = DateFormat.jm().format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: msg.isUser ? AppColors.brandTeal : AppColors.cardBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 16),
              ),
              boxShadow: msg.isUser ? null : AppColors.cardShadow,
            ),
            child: Text(
              msg.text,
              style: AppTypography.bodyMedium.copyWith(
                color: msg.isUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              timeStr,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
          // Suggestion chips
          if (!msg.isUser &&
              msg.suggestions != null &&
              msg.suggestions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.suggestions!.map((s) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _sendMessage(s);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.brandTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.brandTeal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        s,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.brandTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Action buttons — A9-FIX: only on last bot message
          if (!msg.isUser &&
              showActions &&
              msg.actions != null &&
              msg.actions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: msg.actions!.map((a) {
                  final isConfirm = a.value == 'confirm';
                  final isNavigate = a.value == 'navigate';
                  return ElevatedButton.icon(
                    onPressed: () {
                      if (isNavigate) {
                        final route = a.payload?['route']?.toString();
                        if (route != null && mounted) {
                          // Pass origin/destination as query params for navigation
                          final origin = a.payload?['origin']?.toString();
                          final dest = a.payload?['destination']?.toString();
                          final queryParams = <String, String>{};
                          if (origin != null) queryParams['origin'] = origin;
                          if (dest != null) queryParams['destination'] = dest;
                          if (queryParams.isNotEmpty) {
                            final uri = Uri(path: route, queryParameters: queryParams);
                            context.push(uri.toString());
                          } else {
                            context.push(route);
                          }
                        }
                      } else {
                        _sendMessage(a.value);
                      }
                    },
                    icon: Icon(
                      isConfirm
                          ? Icons.check_circle
                          : isNavigate
                              ? Icons.open_in_new
                              : Icons.refresh,
                      size: 18,
                    ),
                    label: Text(a.label),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConfirm
                          ? AppColors.brandTeal
                          : isNavigate
                              ? AppColors.brandOrange
                              : AppColors.textTertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // D2: Post-load progress indicator
  Widget _buildProgressIndicator() {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final bot = ref.read(botServiceProvider);
    final history = bot.getConversationHistory(userId);
    if (history == null) return const SizedBox.shrink();

    // Only show for post_load flow
    final activeIntent = bot.getActiveIntent(userId);
    if (activeIntent != BotIntentType.postLoad) return const SizedBox.shrink();

    const slots = ['origin', 'destination', 'material', 'weight', 'price',
        'price_type', 'advance_percentage', 'truck_type', 'tyres', 'pickup_date'];
    final filled = bot.getFilledSlotCount(userId, slots);
    final total = slots.length;
    final progress = filled / total;
    final isHi = ref.read(localeProvider).languageCode == 'hi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.brandTeal.withValues(alpha: 0.05),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.brandTeal.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandTeal),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isHi ? 'चरण $filled/$total' : 'Step $filled/$total',
            style: AppTypography.caption.copyWith(
              color: AppColors.brandTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // F-07: Pinned smart input area — shows chips/widgets for the last bot message
  Widget _buildPinnedInputArea() {
    // Find last bot message with suggestions
    BotMessage? lastBot;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (!_messages[i].isUser) {
        lastBot = _messages[i];
        break;
      }
    }
    if (lastBot == null) return const SizedBox.shrink();
    final suggestions = lastBot.suggestions;
    final inputType = lastBot.inputType;
    if (suggestions == null || suggestions.isEmpty) return const SizedBox.shrink();

    final isHi = ref.read(localeProvider).languageCode == 'hi';

    // F-19: Date picker for pickup_date slot
    if (inputType == BotInputType.date) {
      return _buildPinnedDatePicker(suggestions, isHi);
    }

    // F-20: Two-button toggle for price_type
    if (inputType == BotInputType.priceType) {
      return _buildPinnedPriceTypeToggle(isHi);
    }

    // F-17: Material ChoiceChip grid
    if (inputType == BotInputType.material) {
      return _buildPinnedChipRow(suggestions, wrap: true);
    }

    // F-18: Truck type ChoiceChip row
    if (inputType == BotInputType.truckType) {
      return _buildPinnedChipRow(suggestions, wrap: false);
    }

    // F-16/tyres: Tyre count chips
    if (inputType == BotInputType.tyres) {
      return _buildPinnedChipRow(suggestions, wrap: false);
    }

    // Default: scrollable chip row for city / numeric / text
    return _buildPinnedChipRow(suggestions, wrap: false);
  }

  Widget _buildPinnedChipRow(List<String> chips, {required bool wrap}) {
    final chipWidgets = chips.map((s) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _sendMessage(s);
        },
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.brandTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.35)),
          ),
          child: Text(
            s,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }).toList();

    if (wrap) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Wrap(spacing: 6, runSpacing: 6, children: chipWidgets),
      );
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: chipWidgets,
      ),
    );
  }

  // F-19: Date picker widget
  Widget _buildPinnedDatePicker(List<String> quickChips, bool isHi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // Quick date chips
          ...quickChips.map((s) => GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); _sendMessage(s); },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.brandTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.35)),
              ),
              child: Text(s, style: AppTypography.bodySmall.copyWith(
                color: AppColors.brandTeal, fontWeight: FontWeight.w600)),
            ),
          )),
          const Spacer(),
          // Calendar picker button
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null && mounted) {
                _sendMessage(picked.toIso8601String().split('T').first);
              }
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(isHi ? 'तारीख चुनें' : 'Pick date'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandTeal,
              side: BorderSide(color: AppColors.brandTeal.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // F-20: Two-button toggle for price_type
  Widget _buildPinnedPriceTypeToggle(bool isHi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () { HapticFeedback.lightImpact(); _sendMessage('Negotiable'); },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandTeal,
                side: BorderSide(color: AppColors.brandTeal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isHi ? '🤝 Negotiable' : '🤝 Negotiable',
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () { HapticFeedback.lightImpact(); _sendMessage('Fixed'); },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isHi ? '🔒 Fixed' : '🔒 Fixed',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () { _sendMessage('skip'); },
            child: Text('skip', style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    final isHi = ref.read(localeProvider).languageCode == 'hi';
    final userId = ref.read(authServiceProvider).currentUser?.id;
    final hasActiveIntent = userId != null &&
        ref.read(botServiceProvider).getActiveIntent(userId) != null;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // D3: Cancel chip when slot-filling is active
          if (hasActiveIntent)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _sendMessage('cancel');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          isHi ? '✕ रद्द करें' : '✕ Cancel',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
          // Tap-to-toggle mic button — supports both platform STT and Whisper
          Builder(builder: (_) {
            final isActive = _stt.isListening || _aiStt.isRecording;
            final micAvailable = _stt.isAvailable ||
                (ref.watch(aiModelManagerProvider).useAiStt &&
                    ref.watch(aiModelManagerProvider).isReady(AiModelType.stt));
            if (!micAvailable) return const SizedBox.shrink();
            // Show spinner during Whisper transcription
            if (_isTranscribing) {
              return const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.brandTeal,
                      ),
                    ),
                  ),
                ),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _toggleMic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.error
                          : AppColors.brandTealLight,
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isActive ? Icons.stop : Icons.mic,
                      color: isActive ? Colors.white : AppColors.brandTeal,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            );
          }),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_stt.isListening || _aiStt.isRecording || _isTranscribing) ? null : _sendMessage,
              readOnly: _stt.isListening || _aiStt.isRecording || _isTranscribing,
              decoration: InputDecoration(
                hintText: _isTranscribing
                    ? (isHi ? 'ट्रांसक्राइब हो रहा है...' : 'Transcribing...')
                    : (_stt.isListening || _aiStt.isRecording)
                        ? (_partialTranscript.isNotEmpty
                            ? _partialTranscript
                            : (isHi ? 'बोलिए...' : 'Listening...'))
                        : l10n.sendMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _isTranscribing
                    ? AppColors.brandTeal.withValues(alpha: 0.05)
                    : (_stt.isListening || _aiStt.isRecording)
                        ? AppColors.error.withValues(alpha: 0.05)
                        : AppColors.inputBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button — when recording, tapping send stops + transcribes
          Container(
            decoration: BoxDecoration(
              color: AppColors.brandTeal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: (_stt.isListening || _aiStt.isRecording)
                  ? _toggleMic
                  : () => _sendMessage(_controller.text),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}
