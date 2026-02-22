import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../core/services/database_service.dart';
import '../models/bot_intent.dart';
import '../models/bot_response.dart';
import '../models/conversation_state.dart';
import 'entity_extractor.dart';
import 'input_sanitizer.dart';

class BasicBotService {
  Map<String, dynamic> _intentsEn = {};
  Map<String, dynamic> _intentsHi = {};
  final EntityExtractor _entityExtractor = EntityExtractor();
  final InputSanitizer _inputSanitizer = InputSanitizer();
  final Map<String, ConversationState> _conversations = {};
  bool _isLoaded = false;
  DatabaseService? _db; // P2-3/P2-4: optional DB access for data queries

  void setDatabaseService(DatabaseService db) => _db = db;

  Future<void> initialize() async {
    if (_isLoaded) return;
    await _entityExtractor.loadEntities();
    try {
      final enStr =
          await rootBundle.loadString('assets/bot/intents_en.json');
      _intentsEn = json.decode(enStr) as Map<String, dynamic>;
    } catch (_) {
      _intentsEn = _defaultIntentsEn;
    }
    try {
      final hiStr =
          await rootBundle.loadString('assets/bot/intents_hi.json');
      _intentsHi = json.decode(hiStr) as Map<String, dynamic>;
    } catch (_) {
      _intentsHi = _defaultIntentsHi;
    }
    _isLoaded = true;
  }

  static const _prefKey = 'bot_conversation_';

  ConversationState _getState(String userId) {
    return _conversations.putIfAbsent(userId, () => ConversationState());
  }

  // P2-5: Restore conversation from SharedPreferences
  Future<void> restoreConversation(String userId) async {
    if (_conversations.containsKey(userId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_prefKey$userId');
      if (json != null && json.isNotEmpty) {
        _conversations[userId] = ConversationState.deserialize(json);
      }
    } catch (_) {}
  }

  // P2-5: Save conversation to SharedPreferences
  Future<void> saveConversation(String userId) async {
    final state = _conversations[userId];
    if (state == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefKey$userId', state.serialize());
    } catch (_) {}
  }

  // P2-5: Get conversation history for UI restore
  List<BotMessage>? getConversationHistory(String userId) {
    final state = _conversations[userId];
    if (state == null || state.history.isEmpty) return null;
    return List.unmodifiable(state.history);
  }

  // D2/D3: Get active intent for UI indicators
  BotIntentType? getActiveIntent(String userId) {
    return _conversations[userId]?.activeIntent;
  }

  // D2: Count how many of the given slots are filled
  int getFilledSlotCount(String userId, List<String> slots) {
    final state = _conversations[userId];
    if (state == null) return 0;
    return slots.where((s) => state.hasSlot(s)).length;
  }

  // P2-5: Add a message to history (for greeting persistence)
  void addMessageToHistory(String userId, BotMessage message) {
    final state = _getState(userId);
    state.addMessage(message);
    _trimHistory(state);
  }

  // Cap history at 100 messages to prevent SharedPreferences bloat
  static const _maxHistorySize = 100;

  void _trimHistory(ConversationState state) {
    if (state.history.length > _maxHistorySize) {
      state.history.removeRange(0, state.history.length - _maxHistorySize);
    }
  }

  void resetConversation(String userId) {
    _conversations.remove(userId);
    // P2-5: Also clear persisted state
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('$_prefKey$userId');
    });
  }

  void resetAllConversations() {
    _conversations.clear();
  }

  /// Generate a context-aware greeting that includes user's active loads/trips.
  String getContextGreeting({
    required String language,
    String? userRole,
    int activeLoadsCount = 0,
    int activeTripsCount = 0,
    String? verificationStatus,
  }) {
    final isHi = language == 'hi';
    final parts = <String>[];

    if (isHi) {
      parts.add('नमस्ते! मैं Nancy हूँ, आपकी TranZfort हेल्पर।');
    } else {
      parts.add('Hi! I\'m Nancy, your TranZfort helper.');
    }

    // Context info
    final contextParts = <String>[];
    if (activeLoadsCount > 0) {
      contextParts.add(isHi
          ? '$activeLoadsCount active load${activeLoadsCount > 1 ? 's' : ''} हैं'
          : '$activeLoadsCount active load${activeLoadsCount > 1 ? 's' : ''}');
    }
    if (activeTripsCount > 0) {
      contextParts.add(isHi
          ? '$activeTripsCount trip चल रही ${activeTripsCount > 1 ? 'हैं' : 'है'}'
          : '$activeTripsCount active trip${activeTripsCount > 1 ? 's' : ''}');
    }
    if (verificationStatus != null && verificationStatus != 'verified') {
      contextParts.add(isHi
          ? 'वेरिफिकेशन: $verificationStatus'
          : 'Verification: $verificationStatus');
    }

    if (contextParts.isNotEmpty) {
      parts.add(isHi
          ? 'आपके ${contextParts.join(', ')}।'
          : 'You have ${contextParts.join(', ')}.');
    }

    parts.add(isHi
        ? 'लोड पोस्ट करना है या लोड ढूँढना है?'
        : 'Post a load or find loads. What do you need?');

    return parts.join('\n');
  }

  Future<BotResponse> processMessage({
    required String userId,
    required String message,
    required String language,
    String? userRole,
    AppLocalizations? l10n,
  }) async {
    await initialize();
    final state = _getState(userId);

    // Sanitize input: trim, strip tags, truncate, normalize Unicode
    final sanitizedMessage = _inputSanitizer.sanitize(message);
    if (sanitizedMessage.isEmpty) {
      return BotResponse(
        text: language == 'hi' ? 'कृपया कुछ टाइप करें।' : 'Please type something.',
        suggestions: _getQuickSuggestions(language, userRole),
      );
    }

    // Add user message to history
    state.addMessage(BotMessage(text: sanitizedMessage, isUser: true));
    _trimHistory(state);

    // Handle action responses (confirm/reset)
    if (message.toLowerCase() == 'confirm' || message == '✅') {
      return _handleConfirmAction(state, language, l10n);
    }
    if (message.toLowerCase() == 'reset' || message == '❌') {
      state.reset();
      return BotResponse(
        text: _t(language, 'reset', l10n),
        suggestions: _getQuickSuggestions(language, userRole),
      );
    }

    // Correction detection — "nahi", "no", "galat", "wrong", "change", "peeche", "back"
    final lower = message.toLowerCase().trim();
    final correctionWords = [
      'nahi', 'nhi', 'no', 'galat', 'wrong', 'change', 'badlo',
      'peeche', 'back', 'previous', 'undo',
    ];
    final cancelWords = [
      'cancel', 'cancel karo', 'band karo', 'chhodo', 'rehne do',
      'mat karo', 'stop', 'quit',
    ];

    if (cancelWords.any((w) => lower == w || lower.startsWith('$w '))) {
      state.reset();
      return BotResponse(
        text: _t(language, 'reset', l10n),
        suggestions: _getQuickSuggestions(language, userRole),
      );
    }

    if (correctionWords.any((w) => lower == w || lower.startsWith('$w '))) {
      // P1-5: Check if user specified which slot to edit
      final targetSlot = _parseSlotEditTarget(lower);
      if (targetSlot != null && state.hasSlot(targetSlot)) {
        state.clearSlot(targetSlot);
        state.resetRetry(targetSlot);
        final activeIntent = state.activeIntent;
        if (activeIntent != null) {
          return await _generateResponse(
            intent: activeIntent,
            confidence: 1.0,
            state: state,
            language: language,
            userRole: userRole,
            userId: userId,
            l10n: l10n,
          );
        }
      }
      // Fallback: clear last slot
      final cleared = state.clearLastSlot();
      if (cleared != null) {
        final activeIntent = state.activeIntent;
        if (activeIntent != null) {
          return await _generateResponse(
            intent: activeIntent,
            confidence: 1.0,
            state: state,
            language: language,
            userRole: userRole,
            userId: userId,
            l10n: l10n,
          );
        }
      }
      return BotResponse(
        text: _t(language, 'reset', l10n),
        suggestions: _getQuickSuggestions(language, userRole),
      );
    }

    // P1-5: Direct slot edit commands — "change origin to Mumbai", "origin galat hai"
    if (state.activeIntent != null) {
      final targetSlot = _parseSlotEditTarget(lower);
      if (targetSlot != null && state.hasSlot(targetSlot)) {
        state.clearSlot(targetSlot);
        state.resetRetry(targetSlot);
        return await _generateResponse(
          intent: state.activeIntent!,
          confidence: 1.0,
          state: state,
          language: language,
          userRole: userRole,
          userId: userId,
          l10n: l10n,
        );
      }
    }

    // P0-2: During active slot-filling, SKIP intent re-classification entirely.
    // This prevents "25 ton" from triggering faq_pricing, "3000" from triggering
    // other intents, etc. Only classify intent when NOT in a slot-filling flow.
    final bool isSlotFilling = state.activeIntent != null &&
        (state.activeIntent == BotIntentType.postLoad ||
         state.activeIntent == BotIntentType.findLoads) &&
        state.currentSlotBeingFilled != null;

    BotIntent intent;
    if (isSlotFilling) {
      // P0-4: Handle "skip" / "chhodo" during slot-filling
      if (_isSkipCommand(lower)) {
        final currentSlot = state.currentSlotBeingFilled;
        if (currentSlot != null) {
          final defaultVal = _getDefaultForSlot(currentSlot);
          if (defaultVal != null) {
            state.updateSlots({currentSlot: defaultVal});
            state.resetRetry(currentSlot);
          }
        }
        intent = BotIntent(type: state.activeIntent!, confidence: 1.0);
      } else {
        // Stay in current intent — no re-classification
        intent = BotIntent(type: state.activeIntent!, confidence: 1.0);

        // P1-4: Targeted extraction — only extract for the current slot
        final currentSlot = state.currentSlotBeingFilled;
        if (currentSlot != null) {
          final entities = _entityExtractor.extractForSlot(
            message,
            language,
            currentSlot,
            existingSlots: state.allSlots,
          );
          state.updateSlots(entities);

          // BOT-FIX2: If targeted extraction found nothing, try raw input fallback
          if (entities.isEmpty || !state.hasSlot(currentSlot)) {
            _tryRawInputForSlot(state, currentSlot, message.trim());
          }

          // Validate city slots against indian_locations.json
          if (currentSlot == 'origin' || currentSlot == 'destination') {
            final raw = state.getSlot(currentSlot);
            if (raw.isNotEmpty) {
              final resolved = _entityExtractor.resolveCity(raw);
              if (resolved != null && resolved != raw) {
                state.updateSlots({currentSlot: resolved});
              }
            }
          }

          // P0-4: Track retries — if slot STILL not filled after extraction
          if (!state.hasSlot(currentSlot)) {
            state.incrementRetry(currentSlot);
            // Universal escape: auto-skip after 5 failed retries if default exists
            if (state.getRetryCount(currentSlot) >= 5) {
              final defaultVal = _getDefaultForSlot(currentSlot);
              if (defaultVal != null) {
                state.updateSlots({currentSlot: defaultVal});
                state.resetRetry(currentSlot);
              } else {
                // A1-FIX: Hard-abort for required slots (origin/dest/material/weight/price)
                // that have no default. Reset and return a graceful exit message.
                state.reset();
                return BotResponse(
                  text: language == 'hi'
                      ? 'समझ नहीं आया। फिर से शुरू करते हैं।'
                      : 'Having trouble understanding. Let\'s start over.',
                  suggestions: _getQuickSuggestions(language, userRole),
                );
              }
            }
          } else {
            state.resetRetry(currentSlot);
          }
        }
      }
    } else {
      // Normal flow: classify intent and extract all entities
      intent = _classifyIntent(message, language, state);

      final entities = _entityExtractor.extract(
        message,
        language,
        existingSlots: state.allSlots,
      );
      state.updateSlots(entities);

      // Validate city slots
      if (state.activeIntent == BotIntentType.postLoad ||
          intent.type == BotIntentType.postLoad) {
        for (final key in ['origin', 'destination']) {
          final raw = entities[key];
          if (raw != null && raw.isNotEmpty) {
            final resolved = _entityExtractor.resolveCity(raw);
            if (resolved != null && resolved != raw) {
              state.updateSlots({key: resolved});
            }
          }
        }
      }

      if (intent.isHighConfidence &&
          intent.type != BotIntentType.fallback &&
          intent.type != BotIntentType.greeting &&
          intent.type != BotIntentType.thanks) {
        state.setActiveIntent(intent.type);
      }
    }

    // 4. Generate response
    final activeIntent = state.activeIntent ?? intent.type;
    final response = await _generateResponse(
      intent: activeIntent,
      confidence: intent.confidence,
      state: state,
      language: language,
      userRole: userRole,
      userId: userId,
      l10n: l10n,
    );

    // Add bot response to history
    state.addMessage(BotMessage(
      text: response.text,
      isUser: false,
      suggestions: response.suggestions,
      actions: response.actions,
    ));
    _trimHistory(state);

    return response;
  }

  BotIntent _classifyIntent(
      String message, String language, ConversationState state) {
    // Match against BOTH language patterns (Hinglish support)
    // Users often type Hindi in English locale and vice versa
    final primaryData = language == 'hi' ? _intentsHi : _intentsEn;
    final secondaryData = language == 'hi' ? _intentsEn : _intentsHi;

    String bestIntent = 'fallback';
    double bestScore = 0;

    // Score against primary language patterns
    _scorePatterns(primaryData, message, 1.0, (intent, score) {
      if (score > bestScore) {
        bestScore = score;
        bestIntent = intent;
      }
    });

    // Score against secondary language patterns (slight penalty)
    _scorePatterns(secondaryData, message, 0.9, (intent, score) {
      if (score > bestScore) {
        bestScore = score;
        bestIntent = intent;
      }
    });

    // If active intent exists (slot-filling in progress), require a STRONG
    // new intent to override. This prevents slot values like "₹3000/ton"
    // from accidentally triggering faq_how_to_post or other intents.
    if (state.activeIntent != null) {
      final threshold = (state.activeIntent == BotIntentType.postLoad ||
              state.activeIntent == BotIntentType.findLoads)
          ? 0.7
          : 0.4;
      if (bestScore < threshold) {
        return BotIntent(type: state.activeIntent!, confidence: 0.5);
      }
    }

    return BotIntent(
      type: _parseIntentType(bestIntent),
      confidence: bestScore,
    );
  }

  void _scorePatterns(
    Map<String, dynamic> intentsData,
    String message,
    double languageMultiplier,
    void Function(String intent, double score) onScore,
  ) {
    final patterns = intentsData['intents'] as Map<String, dynamic>? ?? {};
    for (final entry in patterns.entries) {
      final intentName = entry.key;
      final intentData = entry.value as Map<String, dynamic>;
      final patternList = intentData['patterns'] as List<dynamic>? ?? [];

      final score = _calculateMatchScore(message, patternList);
      final priority = (intentData['priority'] as num?)?.toDouble() ?? 1.0;
      final adjustedScore = score * (1.0 + priority * 0.1) * languageMultiplier;

      onScore(intentName, adjustedScore);
    }
  }

  double _calculateMatchScore(String message, List<dynamic> patterns) {
    final lowerMessage = message.toLowerCase().trim();
    double bestScore = 0;

    for (final pattern in patterns) {
      final patternStr = pattern.toString().toLowerCase().trim();

      // Exact match bonus — critical for suggestion chips
      if (lowerMessage == patternStr) return 1.0;

      final keywords = patternStr
          .replaceAll(RegExp(r'\{[^}]+\}'), '')
          .split(RegExp(r'\s+'))
          .where((k) => k.length > 1) // Skip single-char words like 'a'
          .toList();

      if (keywords.isEmpty) continue;

      int matches = 0;
      for (final keyword in keywords) {
        if (lowerMessage.contains(keyword)) matches++;
      }

      // Normalize by actual keyword count, not hardcoded 5
      final score = matches / keywords.length;
      bestScore = math.max(bestScore, score);
    }

    return bestScore;
  }

  Future<BotResponse> _generateResponse({
    required BotIntentType intent,
    required double confidence,
    required ConversationState state,
    required String language,
    String? userRole,
    String? userId,
    AppLocalizations? l10n,
  }) async {
    // ── BOT-R1: Role-gate cross-role intents ──
    if (userRole == 'trucker' && intent == BotIntentType.postLoad) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? 'ट्रकर लोड पोस्ट नहीं कर सकते। क्या आप लोड खोजना चाहेंगे?'
            : 'Truckers can\'t post loads. Would you like to find loads instead?',
        suggestions: _getQuickSuggestions(language, userRole),
      );
    }
    if (userRole == 'supplier' && intent == BotIntentType.findLoads) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? 'सप्लायर लोड नहीं खोजते। क्या आप लोड पोस्ट करना चाहेंगे?'
            : 'Suppliers don\'t search for loads. Would you like to post a load?',
        suggestions: _getQuickSuggestions(language, userRole),
      );
    }

    switch (intent) {
      case BotIntentType.postLoad:
        return _generatePostLoadResponse(state, language, l10n);
      case BotIntentType.findLoads:
        return _generateFindLoadsResponse(state, language, l10n);
      // ── BOT-R3: Redirect cross-role navigation intents ──
      case BotIntentType.myLoads:
        if (userRole == 'trucker') {
          // P2-3: For truckers, show truck count and navigate to find loads
          if (_db != null && userId != null) {
            try {
              final trucks = await _db!.getMyTrucks(userId);
              final truckCount = trucks.length;
              final trips = await _db!.getMyTrips(userId);
              final activeTrips = trips.where((t) => t['status'] != 'completed').length;
              return BotResponse(
                text: language == 'hi'
                    ? 'आपके $truckCount ट्रक हैं और $activeTrips एक्टिव ट्रिप हैं। ट्रिप देखें या नए लोड खोजें।'
                    : 'You have $truckCount truck${truckCount == 1 ? '' : 's'} and $activeTrips active trip${activeTrips == 1 ? '' : 's'}.',
                actions: [
                  BotAction(
                    label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
                    value: 'navigate',
                    payload: {'route': '/my-trips'},
                  ),
                  BotAction(
                    label: language == 'hi' ? 'लोड खोजें' : 'Find Loads',
                    value: 'navigate',
                    payload: {'route': '/find-loads'},
                  ),
                ],
              );
            } catch (_) {}
          }
          return BotResponse(
            text: language == 'hi'
                ? 'आपकी ट्रिप देखने के लिए My Trips खोलें।'
                : 'Opening My Trips to view your active trips.',
            actions: [
              BotAction(
                label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
                value: 'navigate',
                payload: {'route': '/my-trips'},
              ),
            ],
          );
        }
        // P2-4: For suppliers, show load status summary
        if (_db != null && userId != null) {
          try {
            final loads = await _db!.getMyLoads(userId);
            final active = loads.where((l) => l['status'] == 'active').length;
            final booked = loads.where((l) => l['status'] == 'booked').length;
            final total = loads.length;
            return BotResponse(
              text: language == 'hi'
                  ? 'आपके लोड: कुल $total, एक्टिव $active, बुक $booked। विवरण देखने के लिए नीचे दबाएं।'
                  : 'Your loads: Total $total, Active $active, Booked $booked. Tap below for details.',
              actions: [
                BotAction(
                  label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
                  value: 'navigate',
                  payload: {'route': '/my-loads'},
                ),
              ],
            );
          } catch (_) {}
        }
        return BotResponse(
          text: language == 'hi'
              ? 'आपके लोड देखने के लिए My Loads खोलें।'
              : 'Opening My Loads to view your posted loads.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
              value: 'navigate',
              payload: {'route': '/my-loads'},
            ),
          ],
        );
      case BotIntentType.myTrips:
        if (userRole == 'supplier') {
          return BotResponse(
            text: language == 'hi'
                ? 'आपके लोड देखने के लिए My Loads खोलें।'
                : 'Opening My Loads to view your posted loads.',
            actions: [
              BotAction(
                label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
                value: 'navigate',
                payload: {'route': '/my-loads'},
              ),
            ],
          );
        }
        // P2-3: Show trip count for truckers
        if (_db != null && userId != null) {
          try {
            final trips = await _db!.getMyTrips(userId);
            final active = trips.where((t) => t['status'] == 'booked' || t['status'] == 'in_transit').length;
            final completed = trips.where((t) => t['status'] == 'completed').length;
            return BotResponse(
              text: language == 'hi'
                  ? 'आपकी ट्रिप: एक्टिव $active, पूर्ण $completed। विवरण देखने के लिए नीचे दबाएं।'
                  : 'Your trips: Active $active, Completed $completed. Tap below for details.',
              actions: [
                BotAction(
                  label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
                  value: 'navigate',
                  payload: {'route': '/my-trips'},
                ),
              ],
            );
          } catch (_) {}
        }
        return BotResponse(
          text: language == 'hi'
              ? 'आपकी ट्रिप देखने के लिए My Trips खोलें।'
              : 'Opening My Trips to view your active trips.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
              value: 'navigate',
              payload: {'route': '/my-trips'},
            ),
          ],
        );
      // Phase 5C: Book Load intent (trucker only)
      case BotIntentType.bookLoad:
        if (userRole == 'supplier') {
          state.reset();
          return BotResponse(
            text: language == 'hi'
                ? 'सप्लायर लोड बुक नहीं करते। क्या आप लोड पोस्ट करना चाहेंगे?'
                : 'Suppliers don\'t book loads. Would you like to post a load?',
            suggestions: _getQuickSuggestions(language, userRole),
          );
        }
        // Navigate to find loads where trucker can book
        if (_db != null && userId != null) {
          try {
            final truck = await _db!.getDefaultTruck(userId);
            if (truck == null) {
              return BotResponse(
                text: language == 'hi'
                    ? 'बुकिंग के लिए पहले एक वेरिफाइड ट्रक जोड़ें। My Fleet खोलें।'
                    : 'Add a verified truck first to book loads. Open My Fleet.',
                actions: [
                  BotAction(
                    label: language == 'hi' ? 'मेरा बेड़ा' : 'My Fleet',
                    value: 'navigate',
                    payload: {'route': '/my-fleet'},
                  ),
                ],
              );
            }
            return BotResponse(
              text: language == 'hi'
                  ? 'लोड बुक करने के लिए Find Loads खोलें। वहाँ से लोड चुनें और Book करें।'
                  : 'Open Find Loads to browse and book. Tap any load, then Book This Load.',
              actions: [
                BotAction(
                  label: language == 'hi' ? 'लोड खोजें' : 'Find Loads',
                  value: 'navigate',
                  payload: {'route': '/find-loads'},
                ),
              ],
            );
          } catch (_) {}
        }
        return BotResponse(
          text: language == 'hi'
              ? 'लोड बुक करने के लिए Find Loads खोलें।'
              : 'Open Find Loads to browse and book loads.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'लोड खोजें' : 'Find Loads',
              value: 'navigate',
              payload: {'route': '/find-loads'},
            ),
          ],
        );
      case BotIntentType.manageFleet:
        if (userRole == 'supplier') {
          return BotResponse(
            text: language == 'hi'
                ? 'सप्लायर के लिए बेड़ा प्रबंधन उपलब्ध नहीं है। अपने लोड देखें।'
                : 'Fleet management is for truckers. View your loads instead.',
            actions: [
              BotAction(
                label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
                value: 'navigate',
                payload: {'route': '/my-loads'},
              ),
            ],
          );
        }
        return BotResponse(
          text: language == 'hi'
              ? 'My Fleet खोलें। यहाँ से ट्रक जोड़ें, हटाएं या अपडेट करें।'
              : 'Opening My Fleet to manage your trucks. Add, remove, or update trucks from here.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'मेरा बेड़ा' : 'My Fleet',
              value: 'navigate',
              payload: {'route': '/my-fleet'},
            ),
            BotAction(
              label: language == 'hi' ? 'ट्रक जोड़ें' : 'Add Truck',
              value: 'navigate',
              payload: {'route': '/add-truck'},
            ),
          ],
        );
      case BotIntentType.checkStatus:
        // F-26: Disambiguation — ask which status the user wants to check
        return BotResponse(
          text: language == 'hi'
              ? 'आप किसका स्टेटस देखना चाहते हैं?'
              : 'Which status would you like to check?',
          suggestions: language == 'hi'
              ? ['वेरिफिकेशन', 'लोड स्टेटस', 'ट्रिप स्टेटस', 'पेमेंट']
              : ['Verification', 'Load Status', 'Trip Status', 'Payment'],
          actions: [
            BotAction(
              label: language == 'hi' ? 'वेरिफिकेशन' : 'Verification',
              value: 'navigate',
              payload: {'route': '/profile'},
            ),
            BotAction(
              label: language == 'hi' ? 'लोड' : 'Loads',
              value: 'navigate',
              payload: {'route': '/my-loads'},
            ),
            BotAction(
              label: language == 'hi' ? 'ट्रिप' : 'Trips',
              value: 'navigate',
              payload: {'route': '/my-trips'},
            ),
          ],
        );
      case BotIntentType.navigateTo:
        return _generateNavigateResponse(state, language, userId);
      case BotIntentType.repeatLoad:
        // P2-2: Navigate to "My Loads" so user can duplicate their last load
        return BotResponse(
          text: language == 'hi'
              ? 'पिछला लोड दोबारा पोस्ट करने के लिए My Loads खोलें और Repost दबाएं।'
              : 'To repeat your last load, open My Loads and tap Repost on any load.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
              value: 'navigate',
              payload: {'route': '/my-loads'},
            ),
            BotAction(
              label: language == 'hi' ? 'नया लोड' : 'New Load',
              value: 'navigate',
              payload: {'route': '/post-load'},
            ),
          ],
        );
      case BotIntentType.greeting:
        return BotResponse(
          text: _t(language, 'greeting', l10n),
          suggestions: _getQuickSuggestions(language, userRole),
        );
      case BotIntentType.thanks:
        return BotResponse(
          text: _t(language, 'thanks', l10n),
        );
      case BotIntentType.faqHowToPost:
        return BotResponse(
          text: _t(language, 'faq_how_to_post', l10n),
          suggestions: _getQuickSuggestions(language, userRole),
        );
      case BotIntentType.faqHowToVerify:
        return BotResponse(
          text: _t(language, 'faq_how_to_verify', l10n),
          suggestions: _getQuickSuggestions(language, userRole),
        );
      case BotIntentType.faqPricing:
        return BotResponse(
          text: _t(language, 'faq_pricing', l10n),
          suggestions: _getQuickSuggestions(language, userRole),
        );
      case BotIntentType.faqSupport:
        return BotResponse(
          text: _t(language, 'faq_support', l10n),
          suggestions: _getQuickSuggestions(language, userRole),
        );
      // B3-FIX: Trip lifecycle intents for truckers
      case BotIntentType.tripAction:
        return BotResponse(
          text: language == 'hi'
              ? 'आपकी एक्टिव ट्रिप देखने के लिए My Trips खोलें।'
              : 'Open My Trips to view your active trip details.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
              value: 'navigate',
              payload: {'route': '/my-trips'},
            ),
          ],
        );
      case BotIntentType.uploadLr:
        return BotResponse(
          text: language == 'hi'
              ? 'LR (Lorry Receipt) अपलोड करने के लिए अपनी एक्टिव ट्रिप खोलें।'
              : 'To upload your LR (Lorry Receipt), open your active trip.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'LR अपलोड करें' : 'Upload LR',
              value: 'navigate',
              payload: {'route': '/my-trips'},
            ),
          ],
        );
      case BotIntentType.uploadPod:
        return BotResponse(
          text: language == 'hi'
              ? 'POD (Proof of Delivery) अपलोड करने के लिए अपनी एक्टिव ट्रिप खोलें।'
              : 'To upload your POD (Proof of Delivery), open your active trip.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'POD अपलोड करें' : 'Upload POD',
              value: 'navigate',
              payload: {'route': '/my-trips'},
            ),
          ],
        );
      // B4-FIX: Super Load intent for suppliers
      case BotIntentType.superLoad:
        return BotResponse(
          text: language == 'hi'
              ? 'Super Load एक प्रीमियम सेवा है जहाँ TranZfort admin आपके लिए गारंटीड ट्रक ढूंढता है। जल्दी और भरोसेमंद ट्रांसपोर्ट चाहिए।'
              : 'Super Load is a premium service where TranZfort admin finds you a guaranteed truck. Ideal for suppliers who need fast, reliable transport.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'Super Load अनुरोध' : 'Request Super Load',
              value: 'navigate',
              payload: {'route': '/super-ops/request'},
            ),
          ],
          suggestions: language == 'hi'
              ? ['और जानें', 'लोड पोस्ट करें', 'मदद']
              : ['Learn More', 'Post a Load', 'Help'],
        );
      case BotIntentType.fallback:
        return _generateFallback(language, userRole, l10n);
    }
  }

  // ── BOT-R4: Role-aware fallback ──
  BotResponse _generateFallback(String language, String? userRole, AppLocalizations? l10n) {
    String text;
    if (userRole == 'supplier') {
      text = language == 'hi'
          ? 'समझ नहीं आया। मैं आपकी मदद कर सकता हूं: लोड पोस्ट करें, अपने लोड देखें, वेरिफिकेशन चेक करें, या सवाल पूछें।'
          : 'Didn\'t understand. I can help you post a load, view your loads, check verification, or answer questions.';
    } else if (userRole == 'trucker') {
      text = language == 'hi'
          ? 'समझ नहीं आया। मैं आपकी मदद कर सकता हूं: लोड खोजें, अपनी ट्रिप देखें, फ्लीट मैनेज करें, या सवाल पूछें।'
          : 'Didn\'t understand. I can help you find loads, view your trips, manage fleet, or answer questions.';
    } else {
      text = _t(language, 'fallback', l10n);
    }
    return BotResponse(
      text: text,
      suggestions: _getQuickSuggestions(language, userRole),
      intentType: 'fallback',
      confidence: 0.0,
    );
  }

  Future<BotResponse> _generateNavigateResponse(
      ConversationState state, String language, String? userId) async {
    final origin = state.getSlot('origin');
    final dest = state.getSlot('destination');

    // Both origin and destination extracted — open navigation directly
    if (origin.isNotEmpty && dest.isNotEmpty) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? '$origin से $dest का रास्ता खोल रहा हूँ...'
            : 'Opening navigation from $origin to $dest...',
        actions: [
          BotAction(
            label: 'नेविगेट',
            value: 'navigate',
            payload: {
              'route': '/navigation',
              'origin': origin,
              'destination': dest,
            },
          ),
        ],
      );
    }

    // Only destination extracted — open navigation with destination pre-filled
    if (dest.isNotEmpty) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? '$dest का रास्ता खोल रहा हूँ...'
            : 'Opening navigation to $dest...',
        actions: [
          BotAction(
            label: 'Navigate to $dest',
            value: 'navigate',
            payload: {
              'route': '/navigation',
              'destination': dest,
            },
          ),
        ],
      );
    }

    // Only origin extracted — open navigation with origin pre-filled
    if (origin.isNotEmpty) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? '$origin से नेविगेशन खोल रहा हूँ...'
            : 'Opening navigation from $origin...',
        actions: [
          BotAction(
            label: 'Navigate from $origin',
            value: 'navigate',
            payload: {
              'route': '/navigation',
              'origin': origin,
              'destination': dest,
            },
          ),
        ],
      );
    }

    // Only destination extracted — open navigation with destination pre-filled
    if (dest.isNotEmpty) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? '$dest का रास्ता खोल रहा हूँ...'
            : 'Opening navigation to $dest...',
        actions: [
          BotAction(
            label: language == 'hi' ? '$dest का रास्ता' : 'Navigate to $dest',
            value: 'navigate',
            payload: {
              'route': '/navigation',
              'destination': dest,
            },
          ),
        ],
      );
    }

    // Only origin extracted — open navigation with origin pre-filled
    if (origin.isNotEmpty) {
      state.reset();
      return BotResponse(
        text: language == 'hi'
            ? '$origin से नेविगेशन खोल रहा हूँ...'
            : 'Opening navigation from $origin...',
        actions: [
          BotAction(
            label: language == 'hi' ? '$origin से नेविगेट' : 'Navigate from $origin',
            value: 'navigate',
            payload: {
              'route': '/navigation',
              'origin': origin,
            },
          ),
        ],
      );
    }

    // GPS-8.6: No cities extracted — check for active trip and offer to navigate it
    if (_db != null && userId != null) {
      try {
        final trips = await _db!.getMyTrips(userId);
        final activeTrip = trips.cast<Map<String, dynamic>>().where(
            (t) => t['status'] == 'in_transit' || t['status'] == 'booked',
        ).toList();
        if (activeTrip.isNotEmpty) {
          final trip = activeTrip.first;
          final tripOrigin = trip['origin_city'] as String? ?? '';
          final tripDest = trip['dest_city'] as String? ?? '';
          final material = trip['material'] as String? ?? '';
          state.reset();
          return BotResponse(
            text: language == 'hi'
                ? 'आपकी एक एक्टिव ट्रिप है: $tripOrigin से $tripDest ($material)। क्या इसका रास्ता दिखाऊँ?'
                : 'You have an active trip: $tripOrigin to $tripDest ($material). Navigate this trip?',
            actions: [
              BotAction(
                label: language == 'hi' ? 'ट्रिप नेविगेट करें' : 'Navigate Trip',
                value: 'navigate',
                payload: {
                  'route': '/navigation',
                  'origin': tripOrigin,
                  'destination': tripDest,
                },
              ),
              BotAction(
                label: language == 'hi' ? 'कहीं और' : 'Somewhere else',
                value: 'navigate',
                payload: {'route': '/navigation'},
              ),
            ],
          );
        }
      } catch (_) {}
    }

    // No cities, no active trip — open navigation home
    state.reset();
    return BotResponse(
      text: language == 'hi'
          ? 'नेविगेशन खोल रहा हूँ। कहाँ जाना है बताइए!'
          : 'Opening navigation. Where would you like to go?',
      actions: [
        BotAction(
          label: language == 'hi' ? 'नेविगेट' : 'Navigate',
          value: 'navigate',
          payload: {'route': '/navigation'},
        ),
      ],
    );
  }

  BotResponse _generatePostLoadResponse(
      ConversationState state, String language, AppLocalizations? l10n) {
    if (!state.hasSlot('origin')) {
      return BotResponse(
        text: language == 'hi'
            ? '📍 लोड कहाँ से उठाना है? शहर का नाम टाइप करें या नीचे से चुनें 👇'
            : '📍 Where to pick up the load? Type a city name or pick below 👇',
        suggestions: _getCitySuggestions(),
        inputType: BotInputType.city,
      );
    }
    if (!state.hasSlot('destination')) {
      return BotResponse(
        text: language == 'hi'
            ? '📍 लोड कहाँ पहुँचाना है? शहर का नाम टाइप करें या नीचे से चुनें 👇'
            : '📍 Where to deliver? Type a city name or pick below 👇',
        suggestions: _getCitySuggestions(),
        inputType: BotInputType.city,
      );
    }
    if (!state.hasSlot('material')) {
      final retries = state.getRetryCount('material');
      String text;
      if (retries >= 2) {
        text = language == 'hi'
            ? '📦 कृपया नीचे से material चुनें या नाम टाइप करें (जैसे "Steel", "Cement")'
            : '📦 Please pick a material below or type the name (e.g. "Steel", "Cement")';
      } else {
        text = _t(language, 'ask_material', l10n);
      }
      return BotResponse(
        text: text,
        suggestions: _getMaterialSuggestions(),
        inputType: BotInputType.material,
      );
    }
    if (!state.hasSlot('weight')) {
      final retries = state.getRetryCount('weight');
      String hint;
      List<String> suggestions = ['1 ton', '5 tonnes', '10 tonnes', '15 tonnes', '20 tonnes', '25 tonnes', '30 tonnes', '40 tonnes'];
      if (retries >= 3) {
        hint = language == 'hi'
            ? '⚖️ सिर्फ नंबर टाइप करें (जैसे "25") या "skip" बोलें'
            : '⚖️ Type just the number (e.g. "25") or say "skip"';
        suggestions = ['10', '15', '20', '25', '30', 'skip'];
      } else if (retries >= 2) {
        hint = language == 'hi'
            ? '⚖️ कृपया सिर्फ नंबर टाइप करें, जैसे "25" (टन में)'
            : '⚖️ Please type just the number, e.g. "25" for 25 tonnes';
      } else {
        hint = language == 'hi'
            ? '⚖️ कितना वजन है? (टन में, जैसे 10 या 5-15)'
            : '⚖️ How much weight? (in tonnes, e.g. 10 or 5-15)';
      }
      return BotResponse(
        text: hint,
        suggestions: suggestions,
        inputType: BotInputType.numeric,
      );
    }
    if (!state.hasSlot('price')) {
      final retries = state.getRetryCount('price');
      String text;
      List<String> suggestions = ['₹1500/ton', '₹2000/ton', '₹2500/ton', '₹3000/ton'];
      if (retries >= 3) {
        text = language == 'hi'
            ? '💰 सिर्फ नंबर टाइप करें (जैसे "2500") या "skip" बोलें'
            : '💰 Type just the number (e.g. "2500") or say "skip"';
        suggestions = ['1500', '2000', '2500', '3000', 'skip'];
      } else if (retries >= 2) {
        text = language == 'hi'
            ? '💰 कृपया सिर्फ नंबर टाइप करें, जैसे "2500" (₹ प्रति टन)'
            : '💰 Please type just the number, e.g. "2500" for ₹2500/ton';
      } else {
        text = _t(language, 'ask_price', l10n);
      }
      return BotResponse(
        text: text,
        suggestions: suggestions,
        inputType: BotInputType.numeric,
      );
    }
    // P1-2: Price type slot
    if (!state.hasSlot('price_type')) {
      return BotResponse(
        text: language == 'hi'
            ? '💰 यह rate negotiable है या fixed?'
            : '💰 Is this price negotiable or fixed?',
        suggestions: ['Negotiable', 'Fixed', 'skip'],
        inputType: BotInputType.priceType,
      );
    }
    // P1-3: Advance percentage slot
    if (!state.hasSlot('advance_percentage')) {
      return BotResponse(
        text: language == 'hi'
            ? '💵 कितना advance चाहिए? (50-100%)'
            : '💵 What advance percentage? (50-100%)',
        suggestions: ['70%', '80%', '90%', '100%', 'skip'],
        inputType: BotInputType.numeric,
      );
    }
    if (!state.hasSlot('truck_type')) {
      final retries = state.getRetryCount('truck_type');
      List<String> suggestions = ['Any', 'Open', 'Container', 'Trailer', 'Tanker'];
      if (retries >= 3) suggestions = ['Any', 'Open', 'Container', 'Trailer', 'Tanker', 'skip'];
      return BotResponse(
        text: retries >= 2
            ? (language == 'hi'
                ? '🚛 नीचे से ट्रक टाइप चुनें या "skip" बोलें'
                : '🚛 Pick a truck type below or say "skip"')
            : _t(language, 'ask_truck_type', l10n),
        suggestions: suggestions,
        inputType: BotInputType.truckType,
      );
    }
    if (!state.hasSlot('tyres')) {
      final retries = state.getRetryCount('tyres');
      List<String> suggestions = ['Any', '6', '10', '12', '14', '16', '18', '22'];
      if (retries >= 2) suggestions = ['Any', '6', '10', '12', '14', '16', '18', '22', 'skip'];
      final hint = retries >= 2
          ? (language == 'hi'
              ? '🛞 नीचे से चुनें या "skip" बोलें'
              : '🛞 Pick below or say "skip"')
          : (language == 'hi'
              ? '🛞 कितने टायर का ट्रक चाहिए? (या "Any" चुनें)'
              : '🛞 How many tyres? (or pick "Any")');
      return BotResponse(
        text: hint,
        suggestions: suggestions,
        inputType: BotInputType.tyres,
      );
    }
    if (!state.hasSlot('pickup_date')) {
      final retries = state.getRetryCount('pickup_date');
      List<String> suggestions = language == 'hi'
          ? ['आज', 'कल', 'परसों']
          : ['Today', 'Tomorrow', 'Day after'];
      if (retries >= 2) suggestions = [...suggestions, 'skip'];
      return BotResponse(
        text: retries >= 2
            ? (language == 'hi'
                ? '📅 नीचे से चुनें या "skip" बोलें'
                : '📅 Pick below or say "skip"')
            : _t(language, 'ask_pickup_date', l10n),
        suggestions: suggestions,
        inputType: BotInputType.date,
      );
    }

    // P2-1: Notes slot — optional free text
    if (!state.hasSlot('notes')) {
      return BotResponse(
        text: language == 'hi'
            ? '📝 कोई विशेष जरूरत? (या "no" / "skip" बोलें)'
            : '📝 Any special requirements? (or say "no" / "skip")',
        suggestions: language == 'hi'
            ? ['नहीं', 'skip']
            : ['No', 'skip'],
      );
    }

    // All slots filled — show confirmation (only once)
    final origin = state.getSlot('origin');
    final dest = state.getSlot('destination');
    final material = state.getSlot('material');
    final weight = state.getSlot('weight');
    final price = state.getSlot('price');
    final priceType = state.getSlot('price_type');
    final advancePct = state.getSlot('advance_percentage');
    final truckType = state.getSlot('truck_type');
    final tyres = state.getSlot('tyres');
    final pickupDate = state.getSlot('pickup_date');
    final notes = state.getSlot('notes');

    final loadPayload = {
      'action': 'post_load',
      'origin': origin,
      'destination': dest,
      'material': material,
      'weight': weight,
      'price': price,
      'price_type': priceType,
      'advance_percentage': advancePct,
      'truck_type': truckType,
      'tyres': tyres,
      'pickup_date': pickupDate,
      if (notes.isNotEmpty && notes.toLowerCase() != 'no' && notes.toLowerCase() != 'none')
        'notes': notes,
    };

    // BOT-FIX1: If confirmation was already shown, nudge user to confirm or reset
    if (state.confirmationShown) {
      final nudge = language == 'hi'
          ? 'Post Load dabayein ya Start Over dabayein.'
          : 'Tap Post Load to confirm, or Start Over to restart.';
      return BotResponse(
        text: nudge,
        actions: [
          BotAction(label: 'Post Load', value: 'confirm', payload: loadPayload),
          BotAction(label: 'Start Over', value: 'reset'),
        ],
      );
    }

    state.confirmationShown = true;

    final tyresDisplay = (tyres.isEmpty || tyres.toLowerCase() == 'any') ? 'Any' : '$tyres tyres';
    final priceTypeDisplay = priceType.isNotEmpty ? priceType : 'Negotiable';
    final advanceDisplay = advancePct.isNotEmpty ? '$advancePct%' : '80%';
    final notesDisplay = (notes.isNotEmpty && notes.toLowerCase() != 'no' && notes.toLowerCase() != 'none')
        ? '\n• Notes: $notes' : '';
    final confirmText = language == 'hi'
        ? 'Ready to post:\n$origin se $dest  |  $material  |  $weight tonne  |  Rs $price/tonne ($priceTypeDisplay)\nAdvance: $advanceDisplay  |  Truck: $truckType  |  $tyresDisplay  |  Pickup: $pickupDate$notesDisplay\n\nPost karein?'
        : 'Ready to post:\n$origin to $dest  |  $material  |  $weight tonnes  |  Rs $price/ton ($priceTypeDisplay)\nAdvance: $advanceDisplay  |  Truck: $truckType  |  $tyresDisplay  |  Pickup: $pickupDate$notesDisplay\n\nPost it?';

    final spokenText = language == 'hi'
        ? '$origin se $dest. $material. $weight tonne. $price rupaye per tonne. $truckType. Pickup $pickupDate. Post karein?'
        : '$origin to $dest. $material. $weight tonnes. $price rupees per tonne. $truckType. Pickup $pickupDate. Shall I post it?';

    return BotResponse(
      text: confirmText,
      spokenText: spokenText,
      actions: [
        BotAction(label: 'Post Load', value: 'confirm', payload: loadPayload),
        BotAction(label: 'Start Over', value: 'reset'),
      ],
    );
  }

  BotResponse _generateFindLoadsResponse(
      ConversationState state, String language, AppLocalizations? l10n) {
    if (!state.hasSlot('origin') && !state.hasSlot('destination')) {
      return BotResponse(
        text: _t(language, 'ask_search_city', l10n),
        suggestions: _getCitySuggestions(),
      );
    }

    // P1-7: Ask optional truck type preference
    if (!state.hasSlot('search_truck_type')) {
      return BotResponse(
        text: language == 'hi'
            ? '🚛 किस ट्रक टाइप के लोड चाहिए? (या "Any" चुनें)'
            : '🚛 What truck type loads? (or pick "Any")',
        suggestions: ['Any', 'Open', 'Container', 'Trailer', 'Tanker', 'skip'],
      );
    }

    // P1-7: Ask optional material preference
    if (!state.hasSlot('search_material')) {
      return BotResponse(
        text: language == 'hi'
            ? '📦 किस material के लोड चाहिए? (या "Any" चुनें)'
            : '📦 What material loads? (or pick "Any")',
        suggestions: ['Any', 'Steel', 'Cement', 'Coal', 'Agriculture', 'skip'],
      );
    }

    final origin = state.getSlot('origin');
    final dest = state.getSlot('destination');
    final truckType = state.getSlot('search_truck_type');
    final material = state.getSlot('search_material');

    final parts = <String>[];
    if (origin.isNotEmpty) parts.add(language == 'hi' ? '• से: $origin' : '• From: $origin');
    if (dest.isNotEmpty) parts.add(language == 'hi' ? '• तक: $dest' : '• To: $dest');
    if (truckType.isNotEmpty && truckType.toLowerCase() != 'any') {
      parts.add(language == 'hi' ? '• ट्रक: $truckType' : '• Truck: $truckType');
    }
    if (material.isNotEmpty && material.toLowerCase() != 'any') {
      parts.add(language == 'hi' ? '• सामान: $material' : '• Material: $material');
    }

    final searchText = language == 'hi'
        ? 'लोड खोज रहे हैं:\n${parts.join('\n')}'
        : 'Searching loads:\n${parts.join('\n')}';

    return BotResponse(
      text: searchText,
      actions: [
        BotAction(
          label: language == 'hi' ? 'खोजें' : 'Search',
          value: 'confirm',
          payload: {
            'action': 'find_loads',
            'origin': origin,
            'destination': dest,
            if (truckType.isNotEmpty && truckType.toLowerCase() != 'any')
              'truck_type': truckType,
            if (material.isNotEmpty && material.toLowerCase() != 'any')
              'material': material,
          },
        ),
        BotAction(label: language == 'hi' ? 'फिर से शुरू करें' : 'Start Over', value: 'reset'),
      ],
    );
  }

  BotResponse _handleConfirmAction(
      ConversationState state, String language, AppLocalizations? l10n) {
    final intent = state.activeIntent;
    if (intent == null) {
      return BotResponse(
        text: _t(language, 'fallback', l10n),
        suggestions: _getQuickSuggestions(language, null),
      );
    }

    // Return action payload for the UI to execute
    final payload = <String, dynamic>{};
    for (final entry in state.allSlots.entries) {
      if (entry.value != null) payload[entry.key] = entry.value;
    }
    payload['action'] =
        intent == BotIntentType.postLoad ? 'post_load' : 'find_loads';

    // Phase 5D: Load immutability message after post_load confirm
    final successText = intent == BotIntentType.postLoad
        ? (language == 'hi'
            ? 'हो गया! लोड पोस्ट हो रहा है। ध्यान रहे — लोड लाइव होने के बाद एडिट नहीं होगा।'
            : 'Done! Posting your load. Note — once live, the load cannot be edited.')
        : (language == 'hi'
            ? 'हो गया! आपका अनुरोध प्रोसेस हो रहा है...'
            : 'Done! Processing your request...');

    state.reset();

    return BotResponse(
      text: successText,
      action: BotAction(label: 'execute', value: 'execute', payload: payload),
    );
  }

  // --- Localized text helper ---
  String _t(String language, String key, AppLocalizations? l10n) {
    if (l10n != null) {
      return _getL10nText(key, l10n);
    }
    return _fallbackTexts[language]?[key] ??
        _fallbackTexts['en']?[key] ??
        'I can help you with posting or finding loads.';
  }

  String _getL10nText(String key, AppLocalizations l10n) {
    switch (key) {
      case 'greeting':
        return l10n.botGreeting;
      case 'thanks':
        return l10n.botThanks;
      case 'fallback':
        return l10n.botDidntUnderstand;
      case 'ask_origin':
        return l10n.botAskOrigin;
      case 'ask_destination':
        return l10n.botAskDestination;
      case 'ask_material':
        return l10n.botAskMaterial;
      case 'ask_weight':
        return l10n.botAskWeight;
      case 'ask_price':
        return l10n.botAskPrice;
      case 'ask_truck_type':
        return l10n.botAskTruckType;
      case 'ask_pickup_date':
        return l10n.botAskPickupDate;
      case 'ask_search_city':
        return l10n.botAskOrigin;
      case 'reset':
        return l10n.botGreeting;
      case 'faq_how_to_post':
        return l10n.botHelpPostLoad;
      case 'faq_how_to_verify':
        return l10n.botHelpVerify;
      case 'faq_pricing':
        return l10n.botHelpPricing;
      case 'faq_support':
        return l10n.botHelpSupport;
      default:
        return l10n.botDidntUnderstand;
    }
  }

  // --- Role-aware suggestions ---
  // ── BOT-R2: Role-specific suggestion chips ──
  List<String> _getQuickSuggestions(String language, [String? userRole]) {
    if (language == 'hi') {
      if (userRole == 'supplier') {
        return ['लोड भेजना है', 'मेरे लोड', 'वेरिफिकेशन', 'मदद'];
      } else if (userRole == 'trucker') {
        return ['लोड खोजें', 'मेरी ट्रिप', 'नेविगेट', 'मदद'];
      }
      return ['लोड भेजना है', 'लोड खोजें', 'मदद', 'वेरिफिकेशन'];
    }
    if (userRole == 'supplier') {
      return ['Post a Load', 'My Loads', 'Verification', 'Help'];
    } else if (userRole == 'trucker') {
      return ['Find Loads', 'My Trips', 'Navigate', 'Help'];
    }
    return ['Post a Load', 'Find Loads', 'Help', 'Verification'];
  }

  List<String> _getCitySuggestions() {
    return [
      'Mumbai', 'Delhi', 'Bangalore', 'Pune', 'Chennai', 'Hyderabad',
      'Ahmedabad', 'Jaipur', 'Kolkata', 'Lucknow', 'Nagpur', 'Indore',
    ];
  }

  List<String> _getMaterialSuggestions() {
    return ['Steel', 'Cement', 'Coal', 'Sand', 'Rice', 'Wheat'];
  }

  // P1-5: Parse slot edit target from user message
  // Maps EN and HI slot name keywords to internal slot keys
  String? _parseSlotEditTarget(String lower) {
    const slotKeywords = <String, String>{
      // Origin
      'origin': 'origin', 'starting': 'origin', 'from': 'origin',
      'pickup': 'origin', 'se': 'origin', 'shuru': 'origin',
      // Destination
      'destination': 'destination', 'dest': 'destination', 'to': 'destination',
      'deliver': 'destination', 'drop': 'destination', 'ending': 'destination',
      'tak': 'destination', 'pahunchana': 'destination',
      // Material
      'material': 'material', 'saman': 'material', 'maal': 'material',
      // Weight
      'weight': 'weight', 'vajan': 'weight', 'wajan': 'weight', 'bhar': 'weight',
      // Price
      'price': 'price', 'rate': 'price', 'keemat': 'price', 'daam': 'price',
      // Truck type
      'truck': 'truck_type', 'truck_type': 'truck_type', 'gaadi': 'truck_type',
      // Tyres
      'tyre': 'tyres', 'tyres': 'tyres', 'tire': 'tyres', 'chakka': 'tyres',
      'pahiya': 'tyres',
      // Pickup date
      'date': 'pickup_date', 'pickup_date': 'pickup_date', 'tarikh': 'pickup_date',
      'din': 'pickup_date',
    };

    for (final entry in slotKeywords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  // P0-4: Skip command detection
  bool _isSkipCommand(String lower) {
    const skipWords = ['skip', 'chhodo', 'छोड़ो', 'rehne do', 'next', 'aage'];
    return skipWords.any((w) => lower == w || lower.startsWith('$w '));
  }

  // P0-4: Default values for skipped slots
  String? _getDefaultForSlot(String slot) {
    switch (slot) {
      case 'price_type': return 'Negotiable';
      case 'advance_percentage': return '80';
      case 'truck_type': return 'Any';
      case 'tyres': return 'any';
      case 'pickup_date':
        return DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first;
      case 'notes': return 'None';
      case 'search_truck_type': return 'Any';
      case 'search_material': return 'Any';
      default: return null; // origin, dest, material, weight, price cannot be skipped
    }
  }

  // BOT-FIX2 + P0-3: Raw input fallback for slot-filling when extraction fails
  void _tryRawInputForSlot(ConversationState state, String slot, String trimmed) {
    if (trimmed.isEmpty || trimmed.length >= 100) return;

    switch (slot) {
      case 'origin':
      case 'destination':
        final resolved = _entityExtractor.resolveCity(trimmed);
        if (resolved != null) {
          state.updateSlots({slot: resolved});
        } else if (trimmed.length >= 2) {
          // LOOP-FIX: Accept raw city input to prevent infinite loop.
          // Title-case the input so it looks clean in confirmation.
          final titleCased = trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
          state.updateSlots({slot: titleCased});
        }
        break;
      case 'material':
        state.updateSlots({slot: trimmed});
        break;
      case 'weight':
        // A3-FIX: Use firstMatch to avoid double-decimal corruption
        final weightMatch = RegExp(r'\d+(?:\.\d+)?').firstMatch(trimmed);
        if (weightMatch != null) {
          final val = double.tryParse(weightMatch.group(0)!);
          // A5-FIX: Reject implausible weight values (> 10,000 tonnes)
          if (val != null && val > 0 && val <= 10000) {
            state.updateSlots({slot: weightMatch.group(0)!});
          }
        } else {
          final hindiVal = EntityExtractor.parseHindiNumber(trimmed);
          if (hindiVal != null && hindiVal > 0 && hindiVal <= 10000) {
            state.updateSlots({slot: hindiVal.toStringAsFixed(hindiVal == hindiVal.roundToDouble() ? 0 : 1)});
          }
        }
        break;
      case 'price':
        // A3-FIX: Use firstMatch to avoid double-decimal corruption
        final priceMatch = RegExp(r'\d+(?:\.\d+)?').firstMatch(trimmed);
        if (priceMatch != null) {
          final val = double.tryParse(priceMatch.group(0)!);
          // A5-FIX: Reject implausible price values (< ₹100)
          if (val != null && val >= 100) {
            state.updateSlots({slot: priceMatch.group(0)!});
          }
        } else {
          final hindiVal = EntityExtractor.parseHindiNumber(trimmed);
          if (hindiVal != null && hindiVal >= 100) {
            state.updateSlots({slot: hindiVal.toStringAsFixed(hindiVal == hindiVal.roundToDouble() ? 0 : 1)});
          }
        }
        break;
      case 'truck_type':
        state.updateSlots({slot: trimmed});
        break;
      case 'tyres':
        // A4-FIX: Only accept valid tyre counts
        const validTyres = {6, 10, 12, 14, 16, 18, 22};
        final tyreLt = trimmed.toLowerCase();
        if (tyreLt == 'any' || tyreLt == 'koi bhi' || tyreLt == 'कोई भी') {
          state.updateSlots({slot: 'any'});
        } else {
          final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
          final tyreInt = int.tryParse(digits);
          if (tyreInt != null && validTyres.contains(tyreInt)) {
            state.updateSlots({slot: digits});
          } else if (tyreInt != null && !validTyres.contains(tyreInt)) {
            // Map to nearest valid tyre count
            final nearest = validTyres.reduce((a, b) =>
                (a - tyreInt).abs() <= (b - tyreInt).abs() ? a : b);
            state.updateSlots({slot: nearest.toString()});
          } else {
            final hindiVal = EntityExtractor.parseHindiNumber(trimmed);
            if (hindiVal != null && hindiVal > 0) {
              final hi = hindiVal.round();
              final nearest = validTyres.reduce((a, b) =>
                  (a - hi).abs() <= (b - hi).abs() ? a : b);
              state.updateSlots({slot: nearest.toString()});
            }
          }
        }
        break;
      case 'price_type':
        final lt = trimmed.toLowerCase();
        if (lt.contains('negotiable') || lt.contains('nego') || lt.contains('mol') || lt.contains('mol-tol')) {
          state.updateSlots({slot: 'Negotiable'});
        } else if (lt.contains('fixed') || lt.contains('fix') || lt.contains('pakka') || lt.contains('final')) {
          state.updateSlots({slot: 'Fixed'});
        } else {
          // Accept any input to prevent loop
          state.updateSlots({slot: trimmed});
        }
        break;
      case 'advance_percentage':
        final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isNotEmpty) {
          final val = int.tryParse(digits);
          if (val != null && val >= 0 && val <= 100) {
            state.updateSlots({slot: digits});
          } else if (val != null) {
            // Clamp to valid range
            state.updateSlots({slot: val.clamp(0, 100).toString()});
          }
        } else {
          // Try Hindi number words
          final hindiVal = EntityExtractor.parseHindiNumber(trimmed);
          if (hindiVal != null && hindiVal >= 0 && hindiVal <= 100) {
            state.updateSlots({slot: hindiVal.round().toString()});
          }
        }
        break;
      case 'pickup_date':
        // A2-FIX: Normalize date before storing — never store raw strings like "kal"
        final normalizedDate = _normalizeDateInput(trimmed);
        if (normalizedDate != null) {
          state.updateSlots({slot: normalizedDate});
        }
        break;
      case 'search_truck_type':
        state.updateSlots({slot: trimmed});
        break;
      case 'search_material':
        state.updateSlots({slot: trimmed});
        break;
      case 'notes':
        // Accept any free text; "no"/"nahi" maps to "None"
        final lt = trimmed.toLowerCase();
        if (lt == 'no' || lt == 'nahi' || lt == 'nahi' || lt == 'नहीं' || lt == 'none') {
          state.updateSlots({slot: 'None'});
        } else {
          state.updateSlots({slot: trimmed});
        }
        break;
    }
  }

  // A2-FIX: Normalize raw date input to ISO-8601 date string
  String? _normalizeDateInput(String input) {
    final lower = input.toLowerCase().trim();
    final now = DateTime.now();

    // English keywords
    if (lower == 'today' || lower == 'aaj' || lower == 'आज') {
      return now.toIso8601String().split('T').first;
    }
    if (lower == 'tomorrow' || lower == 'kal' || lower == 'कल') {
      return now.add(const Duration(days: 1)).toIso8601String().split('T').first;
    }
    if (lower == 'day after' || lower == 'day after tomorrow' ||
        lower == 'parso' || lower == 'परसों' || lower == 'परसो') {
      return now.add(const Duration(days: 2)).toIso8601String().split('T').first;
    }
    // "in X days"
    final inDays = RegExp(r'in (\d+) days?').firstMatch(lower);
    if (inDays != null) {
      final d = int.tryParse(inDays.group(1)!);
      if (d != null) return now.add(Duration(days: d)).toIso8601String().split('T').first;
    }
    // Already ISO-8601 format
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return input;
    // DD/MM/YYYY or DD-MM-YYYY
    final dmy = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$').firstMatch(input);
    if (dmy != null) {
      final d = dmy.group(1)!.padLeft(2, '0');
      final m = dmy.group(2)!.padLeft(2, '0');
      final y = dmy.group(3)!;
      return '$y-$m-$d';
    }
    // If nothing matched, return null (slot stays unfilled, retry logic kicks in)
    return null;
  }

  // --- Intent parsing ---
  BotIntentType _parseIntentType(String name) {
    switch (name) {
      case 'post_load':
        return BotIntentType.postLoad;
      case 'find_loads':
        return BotIntentType.findLoads;
      case 'my_loads':
        return BotIntentType.myLoads;
      case 'my_trips':
        return BotIntentType.myTrips;
      case 'check_status':
        return BotIntentType.checkStatus;
      case 'repeat_load':
        return BotIntentType.repeatLoad;
      case 'navigate_to':
        return BotIntentType.navigateTo;
      case 'greeting':
        return BotIntentType.greeting;
      case 'thanks':
        return BotIntentType.thanks;
      case 'faq_how_to_post':
        return BotIntentType.faqHowToPost;
      case 'faq_how_to_verify':
        return BotIntentType.faqHowToVerify;
      case 'faq_pricing':
        return BotIntentType.faqPricing;
      case 'faq_support':
        return BotIntentType.faqSupport;
      case 'manage_fleet':
        return BotIntentType.manageFleet;
      case 'trip_action':
        return BotIntentType.tripAction;
      case 'upload_lr':
        return BotIntentType.uploadLr;
      case 'upload_pod':
        return BotIntentType.uploadPod;
      case 'book_load':
        return BotIntentType.bookLoad;
      case 'super_load':
        return BotIntentType.superLoad;
      default:
        return BotIntentType.fallback;
    }
  }

  // --- Fallback text when ARB not available ---
  // No emoji in any string — these are passed directly to TTS.
  // Short, conversational, natural Hindi/English.
  static const _fallbackTexts = {
    'en': {
      'greeting':
          'Hi! I\'m Nancy, your TranZfort helper. I can post loads or find loads for you. What do you need?',
      'thanks': 'Thanks for using TranZfort! Anything else?',
      'fallback':
          'Didn\'t get that. I can help you post a load, find loads, or answer questions. What do you need?',
      'ask_origin': 'Where from? Type a city or pick one below.',
      'ask_destination': 'Where to? Type a city or pick one.',
      'ask_material': 'What\'s the cargo? Type or pick below.',
      'ask_weight': 'How many tonnes? Type or pick below.',
      'ask_price': 'Rate per tonne? Type or pick.',
      'ask_truck_type': 'What truck type?',
      'ask_pickup_date': 'When to pick up?',
      'ask_search_city': 'Which city? Type or pick one.',
      'reset': 'Sure, let\'s start over. What do you need?',
      'faq_how_to_post':
          'To post a load, go to Dashboard and tap Post Load. Fill in the city, cargo, weight, and price. Or just tell me and I\'ll do it.',
      'faq_how_to_verify':
          'To verify your account, go to Profile and tap Verification. Upload your Aadhaar, PAN, and business documents. We review within 24 hours.',
      'faq_pricing':
          'TranZfort is free. No commission on loads. Super Loads have a small fee.',
      'faq_support':
          'Need help? Email support@tranzfort.com or call 1800-XXX-XXXX. Or tell me your problem.',
    },
    'hi': {
      'greeting':
          'नमस्ते! मैं Nancy हूँ, आपकी TranZfort हेल्पर। लोड पोस्ट करना है या लोड ढूँढना है?',
      'thanks': 'शुक्रिया! कोई और काम हो तो बताएं।',
      'fallback':
          'समझ नहीं आया। लोड पोस्ट करना है, लोड ढूँढना है, या कोई सवाल है?',
      'ask_origin': 'कहाँ से लोड उठाना है? शहर का नाम लिखें या नीचे से चुनें।',
      'ask_destination': 'कहाँ पहुँचाना है? शहर लिखें या चुनें।',
      'ask_material': 'क्या माल भेजना है? लिखें या नीचे से चुनें।',
      'ask_weight': 'कितना माल है, टन में? लिखें या चुनें।',
      'ask_price': 'रेट क्या है, रुपये प्रति टन? लिखें या चुनें।',
      'ask_truck_type': 'कौन सा ट्रक चाहिए?',
      'ask_pickup_date': 'कब उठाना है?',
      'ask_search_city': 'किस शहर में लोड चाहिए? लिखें या चुनें।',
      'reset': 'ठीक है, फिर से शुरू करते हैं। क्या करना है?',
      'faq_how_to_post':
          'लोड पोस्ट करने के लिए Dashboard में जाएं और Post Load दबाएं। शहर, माल, वज़न और रेट भरें। या मुझे बताएं, मैं कर देता हूँ।',
      'faq_how_to_verify':
          'अकाउंट वेरिफाई करने के लिए Profile में जाएं और Verification दबाएं। आधार, PAN और बिज़नेस दस्तावेज़ अपलोड करें। 24 घंटे में समीक्षा हो जाती है।',
      'faq_pricing':
          'TranZfort मुफ़्त है। लोड पर कोई कमीशन नहीं। Super Load पर छोटी फीस लगती है।',
      'faq_support':
          'मदद चाहिए? support@tranzfort.com पर ईमेल करें। या अपनी समस्या बताएं।',
    },
  };

  // --- Default intent data ---
  static final Map<String, dynamic> _defaultIntentsEn = {
    'intents': {
      'greeting': {
        'patterns': [
          'hello',
          'hi',
          'hey',
          'good morning',
          'good afternoon',
          'good evening'
        ],
        'priority': 1,
      },
      'post_load': {
        'patterns': [
          'post a load',
          'post load',
          'send load',
          'ship load',
          'need truck',
          'book truck',
          'transport goods',
          'send material',
          'ship goods',
          'i want to post',
          'create load',
          'new load',
        ],
        'priority': 2,
      },
      'find_loads': {
        'patterns': [
          'find loads',
          'find load',
          'search loads',
          'search load',
          'need load',
          'available loads',
          'looking for load',
          'empty truck',
          'need booking',
          'want load',
          'show loads',
          'get loads',
        ],
        'priority': 2,
      },
      'thanks': {
        'patterns': ['thanks', 'thank you', 'thankyou', 'great', 'awesome'],
        'priority': 1,
      },
      'faq_how_to_post': {
        'patterns': [
          'how to post',
          'how do i post',
          'posting help',
          'help post'
        ],
        'priority': 3,
      },
      'faq_how_to_verify': {
        'patterns': [
          'verification',
          'how to verify',
          'verification help',
          'verify account',
          'kyc',
        ],
        'priority': 3,
      },
      'faq_pricing': {
        'patterns': [
          'pricing',
          'price',
          'cost',
          'charges',
          'commission',
          'fee',
          'how much',
          'rate',
        ],
        'priority': 3,
      },
      'faq_support': {
        'patterns': [
          'help',
          'support',
          'contact',
          'problem',
          'issue',
          'complaint',
        ],
        'priority': 3,
      },
      'my_loads': {
        'patterns': [
          'my loads',
          'my listings',
          'show my loads',
          'posted loads',
          'my posted loads',
          'active loads',
        ],
        'priority': 2,
      },
      'my_trips': {
        'patterns': [
          'my trips',
          'my trip',
          'trip status',
          'active trips',
          'current trip',
          'where is my truck',
          'delivery status',
        ],
        'priority': 2,
      },
      'check_status': {
        'patterns': [
          'verification status',
          'my status',
          'check status',
          'am i verified',
          'account status',
          'kyc status',
        ],
        'priority': 2,
      },
      'manage_fleet': {
        'patterns': [
          'my fleet',
          'my trucks',
          'manage fleet',
          'manage trucks',
          'add truck',
          'fleet management',
          'truck list',
          'show trucks',
          'edit truck',
          'remove truck',
        ],
        'priority': 2,
      },
      'repeat_load': {
        'patterns': [
          'same load again',
          'repeat load',
          'post same load',
          'same load',
          'duplicate load',
          'post again',
          'load again',
          'last load again',
          'repost',
          're-post',
        ],
        'priority': 2,
      },
      'navigate_to': {
        'patterns': [
          'navigate',
          'navigate to',
          'navigation',
          'open navigation',
          'start navigation',
          'go to',
          'take me to',
          'directions to',
          'route to',
          'how to reach',
          'show route',
          'find route',
          'gps',
          'open gps',
          'open map',
        ],
        'priority': 2,
      },
      'trip_action': {
        'patterns': [
          'active trip',
          'current trip detail',
          'trip detail',
          'open trip',
          'view trip',
          'i reached destination',
          'reached destination',
          'i am at pickup',
          'at pickup point',
          'trip info',
        ],
        'priority': 2,
      },
      'upload_lr': {
        'patterns': [
          'upload lr',
          'lorry receipt',
          'upload lorry receipt',
          'lr upload',
          'submit lr',
          'add lr',
          'lr document',
          'pickup receipt',
        ],
        'priority': 3,
      },
      'upload_pod': {
        'patterns': [
          'upload pod',
          'proof of delivery',
          'upload delivery proof',
          'pod upload',
          'submit pod',
          'delivery proof',
          'mark as delivered',
          'delivery done',
          'load delivered',
          'delivery complete',
        ],
        'priority': 3,
      },
      'super_load': {
        'patterns': [
          'super load',
          'guaranteed truck',
          'admin help',
          'managed service',
          'premium truck',
          'urgent truck',
          'guaranteed transport',
          'admin find truck',
          'super load kya hai',
          'what is super load',
        ],
        'priority': 3,
      },
      'book_load': {
        'patterns': [
          'book load',
          'book a load',
          'book this load',
          'i want to book',
          'booking',
          'book karo',
          'le lo',
          'load le lo',
          'load book',
          'accept load',
          'take load',
          'load lena hai',
        ],
        'priority': 2,
      },
    },
  };

  static final Map<String, dynamic> _defaultIntentsHi = {
    'intents': {
      'greeting': {
        'patterns': [
          'namaste',
          'namaskar',
          'hello',
          'hi',
          'kaise ho',
          'pranam'
        ],
        'priority': 1,
      },
      'post_load': {
        'patterns': [
          '\u0932\u094b\u0921 \u092d\u0947\u091c\u0928\u093e \u0939\u0948',
          'load bhejna hai',
          'load post karna hai',
          'truck book karna hai',
          'truck chahiye',
          'transport karna hai',
          'bhejna hai',
          'booking karni hai',
          'load dalna hai',
          'saman bhejna hai',
          'load post',
          'maal bhejna hai',
          'gaadi chahiye',
          'truck lagana hai',
          'load lagao',
          'maal bhejo',
          'truck book karo',
          'saman transport karna hai',
          'load post karo',
          'load dena hai',
          'truck chahiye mujhe',
        ],
        'priority': 2,
      },
      'find_loads': {
        'patterns': [
          '\u0932\u094b\u0921 \u0916\u094b\u091c\u0947\u0902',
          'load dhundna hai',
          'load chahiye',
          'load dhoondna hai',
          'khali truck hai',
          'khali gaadi hai',
          'booking chahiye',
          'load mil sakta hai',
          'kaam chahiye',
          'trip chahiye',
          'load khojo',
          'kaam do',
          'trip do',
          'load batao',
          'khali hun',
          'khali gaadi hai meri',
          'koi load hai kya',
          'load milega kya',
          'kaam chahiye mujhe',
          'load dhundo',
          'trip chahiye mujhe',
        ],
        'priority': 2,
      },
      'thanks': {
        'patterns': ['dhanyawad', 'shukriya', 'thanks', 'bahut accha'],
        'priority': 1,
      },
      'faq_how_to_post': {
        'patterns': [
          'load kaise post kare',
          'load kaise bheje',
          'posting kaise kare'
        ],
        'priority': 3,
      },
      'faq_how_to_verify': {
        'patterns': [
          '\u0935\u0947\u0930\u093f\u092b\u093f\u0915\u0947\u0936\u0928',
          'verify kaise kare',
          'verification kaise hota hai',
          'account verify',
          'verification',
        ],
        'priority': 3,
      },
      'faq_pricing': {
        'patterns': [
          '\u0915\u0940\u092e\u0924',
          'rate kya hai',
          'kitna charge',
          'kitna paisa',
          'price kya hai',
          'commission kitna',
          'keemat',
        ],
        'priority': 3,
      },
      'faq_support': {
        'patterns': [
          '\u092e\u0926\u0926',
          'madad chahiye',
          'madad',
          'help chahiye',
          'problem hai',
          'dikkat hai',
          'support',
        ],
        'priority': 3,
      },
      'my_loads': {
        'patterns': [
          'mere loads',
          'mere loads dikhao',
          'meri listings',
          'mera load',
          'active loads',
          'load status',
          'kitne loads hain',
        ],
        'priority': 2,
      },
      'my_trips': {
        'patterns': [
          'meri trip',
          'meri trips',
          'trip status',
          'trip kahan hai',
          'kahan pahuncha',
          'delivery status',
          'gaadi kahan hai',
          'meri gaadi kahan hai',
          'trip ka status',
          'delivery kab hogi',
          'meri delivery',
          'trip update',
          'gaadi pahunchi kya',
          'delivery hua kya',
        ],
        'priority': 2,
      },
      'check_status': {
        'patterns': [
          'verification status',
          'mera status',
          'status dikhao',
          'verify hua kya',
          'account status',
          'kyc status',
        ],
        'priority': 2,
      },
      'manage_fleet': {
        'patterns': [
          'mera fleet',
          'mere truck',
          'mere trucks',
          'truck dikhao',
          'fleet management',
          'truck jodna hai',
          'truck add karna hai',
          'gaadi jodna hai',
          'truck hatana hai',
          'truck list',
          'truck add karo',
          'nayi gaadi',
          'truck register karna hai',
          'naya truck jodna hai',
          'gaadi register karo',
          'fleet mein truck add karo',
        ],
        'priority': 2,
      },
      'repeat_load': {
        'patterns': [
          'wahi load phir se',
          'same load again',
          'wahi load',
          'phir se load',
          'dobara load',
          'load repeat',
          'load phir se',
          'pichla load',
          'last load',
          'dubara post',
        ],
        'priority': 2,
      },
      'navigate_to': {
        'patterns': [
          'navigate',
          'navigation',
          'rasta dikhao',
          'rasta batao',
          'jaana hai',
          'jana hai',
          'kaise jaye',
          'kaise jaaye',
          'kaise pahunche',
          'kaise pahunchu',
          'rasta chahiye',
          'map dikhao',
          'gps kholo',
          'navigate karo',
          'mujhe jaana hai',
          'meri trip ka rasta',
          'trip ka rasta dikhao',
        ],
        'priority': 2,
      },
      'trip_action': {
        'patterns': [
          'active trip dikhao',
          'trip detail dikhao',
          'main destination pahunch gaya',
          'pickup pe pahunch gaya',
          'trip open karo',
          'meri current trip',
          'trip ki detail',
        ],
        'priority': 2,
      },
      'upload_lr': {
        'patterns': [
          'lr upload karo',
          'lorry receipt upload',
          'lr submit karo',
          'lr dalna hai',
          'pickup receipt upload',
          'lr lagao',
        ],
        'priority': 3,
      },
      'upload_pod': {
        'patterns': [
          'pod upload karo',
          'delivery proof upload',
          'pod submit karo',
          'delivery ho gayi',
          'maal pahunch gaya',
          'delivery complete ho gayi',
          'pod dalna hai',
          'delivery mark karo',
        ],
        'priority': 3,
      },
      'super_load': {
        'patterns': [
          'super load',
          'guaranteed truck chahiye',
          'admin se madad',
          'premium service',
          'urgent truck chahiye',
          'super load kya hai',
          'guaranteed transport chahiye',
          'admin truck dhundega',
        ],
        'priority': 3,
      },
      'book_load': {
        'patterns': [
          'load book karo',
          'book karo',
          'le lo',
          'load le lo',
          'load lena hai',
          'booking karo',
          'load accept karo',
          'yeh load chahiye',
          'load book karna hai',
          'load lena chahta hun',
          'mujhe yeh load chahiye',
          'book kar do',
        ],
        'priority': 2,
      },
    },
  };
}
