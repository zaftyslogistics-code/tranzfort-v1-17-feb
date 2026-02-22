import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/bot_intent.dart';
import '../models/conversation_state.dart';

/// Classifies user messages into intents using keyword matching.
/// Rule-engine first — deterministic, testable, no LLM dependency.
class IntentDetector {
  Map<String, dynamic> _intentsEn = {};
  Map<String, dynamic> _intentsHi = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    if (_isLoaded) return;
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

  /// Classify a user message into an intent.
  /// Matches against BOTH language patterns (Hinglish support).
  BotIntent classify(
    String message,
    String language,
    ConversationState state,
  ) {
    final primaryData = language == 'hi' ? _intentsHi : _intentsEn;
    final secondaryData = language == 'hi' ? _intentsEn : _intentsHi;

    String bestIntent = 'fallback';
    double bestScore = 0;

    _scorePatterns(primaryData, message, 1.0, (intent, score) {
      if (score > bestScore) {
        bestScore = score;
        bestIntent = intent;
      }
    });

    _scorePatterns(secondaryData, message, 0.9, (intent, score) {
      if (score > bestScore) {
        bestScore = score;
        bestIntent = intent;
      }
    });

    // If active intent exists, require a STRONG new intent to override.
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
      type: parseIntentType(bestIntent),
      confidence: bestScore,
    );
  }

  /// Check if the message is a cancel command.
  bool isCancelCommand(String message) {
    final lower = message.toLowerCase().trim();
    const cancelWords = [
      'cancel', 'cancel karo', 'band karo', 'chhodo', 'rehne do',
      'mat karo', 'stop', 'quit',
    ];
    return cancelWords.any((w) => lower == w || lower.startsWith('$w '));
  }

  /// Check if the message is a correction command.
  bool isCorrectionCommand(String message) {
    final lower = message.toLowerCase().trim();
    const correctionWords = [
      'nahi', 'nhi', 'no', 'galat', 'wrong', 'change', 'badlo',
      'peeche', 'back', 'previous', 'undo',
    ];
    return correctionWords.any((w) => lower == w || lower.startsWith('$w '));
  }

  /// Check if the message is a confirmation.
  bool isConfirmation(String message) {
    final lower = message.toLowerCase().trim();
    return lower == 'confirm' || lower == '✅' ||
        lower == 'haan' || lower == 'ha' || lower == 'yes' ||
        lower == 'ok' || lower == 'theek hai';
  }

  /// Check if the message is a skip command.
  bool isSkipCommand(String message) {
    final lower = message.toLowerCase().trim();
    const skipWords = [
      'skip', 'chhodo', 'rehne do', 'nahi chahiye', 'next',
      'aage', 'aage badho', 'छोड़ो',
    ];
    return skipWords.any((w) => lower == w || lower.startsWith('$w '));
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

      if (lowerMessage == patternStr) return 1.0;

      final keywords = patternStr
          .replaceAll(RegExp(r'\{[^}]+\}'), '')
          .split(RegExp(r'\s+'))
          .where((k) => k.length > 1)
          .toList();

      if (keywords.isEmpty) continue;

      int matches = 0;
      for (final keyword in keywords) {
        if (lowerMessage.contains(keyword)) matches++;
      }

      final score = matches / keywords.length;
      bestScore = math.max(bestScore, score);
    }

    return bestScore;
  }

  /// Parse intent string name to enum type.
  static BotIntentType parseIntentType(String name) {
    switch (name) {
      case 'post_load': return BotIntentType.postLoad;
      case 'find_loads': return BotIntentType.findLoads;
      case 'my_loads': return BotIntentType.myLoads;
      case 'my_trips': return BotIntentType.myTrips;
      case 'check_status': return BotIntentType.checkStatus;
      case 'repeat_load': return BotIntentType.repeatLoad;
      case 'navigate_to': return BotIntentType.navigateTo;
      case 'greeting': return BotIntentType.greeting;
      case 'thanks': return BotIntentType.thanks;
      case 'faq_how_to_post': return BotIntentType.faqHowToPost;
      case 'faq_how_to_verify': return BotIntentType.faqHowToVerify;
      case 'faq_pricing': return BotIntentType.faqPricing;
      case 'faq_support': return BotIntentType.faqSupport;
      case 'manage_fleet': return BotIntentType.manageFleet;
      case 'trip_action': return BotIntentType.tripAction;
      case 'upload_lr': return BotIntentType.uploadLr;
      case 'upload_pod': return BotIntentType.uploadPod;
      case 'book_load': return BotIntentType.bookLoad;
      case 'super_load': return BotIntentType.superLoad;
      default: return BotIntentType.fallback;
    }
  }

  // ── Default intent patterns (fallback if JSON files not found) ──

  static final Map<String, dynamic> _defaultIntentsEn = {
    'intents': {
      'post_load': {
        'patterns': [
          'post load', 'post a load', 'create load', 'new load',
          'I want to post', 'load post karna hai', 'naya load',
        ],
        'priority': 2,
      },
      'find_loads': {
        'patterns': [
          'find load', 'find loads', 'search load', 'show loads',
          'load chahiye', 'load dhundho', 'available loads',
        ],
        'priority': 2,
      },
      'my_loads': {
        'patterns': ['my loads', 'mere load', 'posted loads', 'my posted'],
        'priority': 1,
      },
      'my_trips': {
        'patterns': ['my trips', 'meri trip', 'active trips', 'trip status'],
        'priority': 1,
      },
      'check_status': {
        'patterns': ['status', 'check status', 'kya status hai', 'load status'],
        'priority': 1,
      },
      'navigate_to': {
        'patterns': [
          'navigate', 'navigation', 'route', 'raasta dikhao',
          'kaise jaun', 'directions', 'map',
        ],
        'priority': 1,
      },
      'book_load': {
        'patterns': ['book load', 'book karo', 'booking', 'load book'],
        'priority': 2,
      },
      'super_load': {
        'patterns': ['super load', 'premium load', 'guaranteed load'],
        'priority': 2,
      },
      'greeting': {
        'patterns': ['hi', 'hello', 'namaste', 'hey', 'good morning'],
        'priority': 0,
      },
      'thanks': {
        'patterns': ['thanks', 'thank you', 'dhanyavaad', 'shukriya'],
        'priority': 0,
      },
      'faq_how_to_post': {
        'patterns': ['how to post', 'kaise post kare', 'load kaise banaye'],
        'priority': 1,
      },
      'faq_how_to_verify': {
        'patterns': ['how to verify', 'verification kaise', 'kyc kaise'],
        'priority': 1,
      },
      'faq_pricing': {
        'patterns': ['pricing', 'rate kya hai', 'commission', 'charges'],
        'priority': 1,
      },
      'faq_support': {
        'patterns': ['help', 'support', 'problem', 'issue', 'complaint'],
        'priority': 1,
      },
      'manage_fleet': {
        'patterns': ['my trucks', 'fleet', 'add truck', 'truck add'],
        'priority': 1,
      },
      'trip_action': {
        'patterns': ['start trip', 'trip shuru', 'deliver', 'complete trip'],
        'priority': 1,
      },
      'upload_lr': {
        'patterns': ['upload lr', 'lorry receipt', 'lr upload'],
        'priority': 1,
      },
      'upload_pod': {
        'patterns': ['upload pod', 'delivery photo', 'pod upload'],
        'priority': 1,
      },
    },
  };

  static final Map<String, dynamic> _defaultIntentsHi = {
    'intents': {
      'post_load': {
        'patterns': [
          'load post karna hai', 'naya load', 'load banao',
          'maal bhejna hai', 'load post karo', 'load create karo',
        ],
        'priority': 2,
      },
      'find_loads': {
        'patterns': [
          'load chahiye', 'load dhundho', 'load dikhao',
          'available load', 'koi load hai', 'load search karo',
        ],
        'priority': 2,
      },
      'my_loads': {
        'patterns': ['mere load', 'mera load', 'posted load dikhao'],
        'priority': 1,
      },
      'my_trips': {
        'patterns': ['meri trip', 'trip dikhao', 'active trip'],
        'priority': 1,
      },
      'check_status': {
        'patterns': ['status batao', 'kya status hai', 'load ka status'],
        'priority': 1,
      },
      'navigate_to': {
        'patterns': [
          'raasta dikhao', 'navigate karo', 'kaise jaun',
          'route batao', 'map dikhao',
        ],
        'priority': 1,
      },
      'book_load': {
        'patterns': ['load book karo', 'book karna hai', 'booking karo'],
        'priority': 2,
      },
      'super_load': {
        'patterns': ['super load', 'premium load', 'guaranteed load chahiye'],
        'priority': 2,
      },
      'greeting': {
        'patterns': ['namaste', 'namaskar', 'hello', 'hi'],
        'priority': 0,
      },
      'thanks': {
        'patterns': ['dhanyavaad', 'shukriya', 'thanks', 'bahut accha'],
        'priority': 0,
      },
      'faq_how_to_post': {
        'patterns': ['load kaise post kare', 'kaise banaye load'],
        'priority': 1,
      },
      'faq_how_to_verify': {
        'patterns': ['verification kaise kare', 'kyc kaise kare', 'verify kaise'],
        'priority': 1,
      },
      'faq_pricing': {
        'patterns': ['rate kya hai', 'kitna charge', 'commission kitna'],
        'priority': 1,
      },
      'faq_support': {
        'patterns': ['madad chahiye', 'problem hai', 'dikkat hai', 'help'],
        'priority': 1,
      },
      'manage_fleet': {
        'patterns': ['mere truck', 'truck add karo', 'fleet dikhao'],
        'priority': 1,
      },
      'trip_action': {
        'patterns': ['trip shuru karo', 'deliver karo', 'trip complete'],
        'priority': 1,
      },
      'upload_lr': {
        'patterns': ['lr upload karo', 'lorry receipt'],
        'priority': 1,
      },
      'upload_pod': {
        'patterns': ['pod upload karo', 'delivery photo', 'delivery ka photo'],
        'priority': 1,
      },
    },
  };
}
