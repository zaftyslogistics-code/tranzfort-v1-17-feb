import '../models/bot_intent.dart';
import '../models/bot_response.dart';
import '../models/conversation_state.dart';
import 'prompt_composer.dart';

/// Assembles bot responses: text, suggestion chips, and action buttons.
/// Separates response construction from business logic.
class BotResponseBuilder {
  final PromptComposer? _promptComposer;

  BotResponseBuilder([this._promptComposer]);

  /// Build a slot-filling prompt response.
  BotResponse slotPrompt({
    required String promptText,
    required BotIntentType intent,
    required ConversationState state,
    required String language,
    String? userRole,
  }) {
    return BotResponse(
      text: promptText,
      intentType: intent.name,
      confidence: 1.0,
      suggestions: _slotSuggestions(intent, state, language),
    );
  }

  /// Build a confirmation summary response.
  BotResponse confirmation({
    required String summaryText,
    required BotIntentType intent,
    required String language,
  }) {
    final isHi = language == 'hi';
    return BotResponse(
      text: summaryText,
      intentType: intent.name,
      confidence: 1.0,
      suggestions: [
        isHi ? '✅ हाँ, पोस्ट करो' : '✅ Yes, Post',
        isHi ? '❌ रद्द करो' : '❌ Cancel',
        isHi ? '✏️ बदलो' : '✏️ Change',
      ],
    );
  }

  /// Build a success response after an action completes.
  BotResponse success({
    required String text,
    required String language,
    String? userRole,
    List<BotAction>? actions,
  }) {
    return BotResponse(
      text: text,
      suggestions: getQuickSuggestions(language, userRole),
      actions: actions,
    );
  }

  /// Build an error response.
  BotResponse error({
    required String text,
    required String language,
    String? userRole,
  }) {
    return BotResponse(
      text: text,
      suggestions: getQuickSuggestions(language, userRole),
    );
  }

  /// Build a navigation action response.
  BotResponse navigationAction({
    required String text,
    required String route,
    required String label,
    required String language,
    Map<String, dynamic>? payload,
  }) {
    return BotResponse(
      text: text,
      actions: [
        BotAction(
          label: label,
          value: 'navigate',
          payload: {'route': route, ...?payload},
        ),
      ],
    );
  }

  /// Build a role-gate rejection response.
  BotResponse roleGate({
    required String text,
    required String language,
    String? userRole,
  }) {
    return BotResponse(
      text: text,
      suggestions: getQuickSuggestions(language, userRole),
    );
  }

  /// Build a fallback response.
  BotResponse fallback({
    required String language,
    String? userRole,
  }) {
    String text;
    final composer = _promptComposer;
    if (composer != null) {
      text = composer.error('fallback');
    } else {
      text = _defaultFallback(language, userRole);
    }
    return BotResponse(
      text: text,
      suggestions: getQuickSuggestions(language, userRole),
      intentType: 'fallback',
      confidence: 0.0,
    );
  }

  /// Build a reset/cancel response.
  BotResponse reset({
    required String language,
    String? userRole,
  }) {
    final isHi = language == 'hi';
    return BotResponse(
      text: isHi ? 'ठीक है, रद्द कर दिया। और क्या मदद चाहिए?' : 'OK, cancelled. What else can I help with?',
      suggestions: getQuickSuggestions(language, userRole),
    );
  }

  /// Get role-aware quick suggestion chips.
  List<String> getQuickSuggestions(String language, String? userRole) {
    final isHi = language == 'hi';
    if (userRole == 'supplier') {
      return isHi
          ? ['लोड पोस्ट करो', 'मेरे लोड', 'Super Load', 'मदद']
          : ['Post Load', 'My Loads', 'Super Load', 'Help'];
    }
    if (userRole == 'trucker') {
      return isHi
          ? ['लोड खोजो', 'मेरी ट्रिप', 'नेविगेट', 'मदद']
          : ['Find Loads', 'My Trips', 'Navigate', 'Help'];
    }
    return isHi
        ? ['लोड पोस्ट करो', 'लोड खोजो', 'मदद']
        : ['Post Load', 'Find Loads', 'Help'];
  }

  List<String>? _slotSuggestions(
      BotIntentType intent, ConversationState state, String language) {
    final currentSlot = state.currentSlotBeingFilled;
    if (currentSlot == null) return null;

    final isHi = language == 'hi';
    switch (currentSlot) {
      case 'price_type':
        return ['Negotiable', 'Fixed'];
      case 'truck_type':
        return isHi
            ? ['Open Body', 'Closed Body', 'Container', 'Trailer', 'कोई भी']
            : ['Open Body', 'Closed Body', 'Container', 'Trailer', 'Any'];
      case 'tyres':
        return ['6', '10', '12', '14', '16', '18', isHi ? 'कोई भी' : 'Any'];
      case 'notes':
        return [isHi ? 'नहीं' : 'No', isHi ? 'छोड़ो' : 'Skip'];
      default:
        return null;
    }
  }

  String _defaultFallback(String language, String? userRole) {
    if (userRole == 'supplier') {
      return language == 'hi'
          ? 'समझ नहीं आया। मैं आपकी मदद कर सकता हूं: लोड पोस्ट करें, अपने लोड देखें, या सवाल पूछें।'
          : 'Didn\'t understand. I can help you post a load, view your loads, or answer questions.';
    }
    if (userRole == 'trucker') {
      return language == 'hi'
          ? 'समझ नहीं आया। मैं आपकी मदद कर सकता हूं: लोड खोजें, अपनी ट्रिप देखें, या सवाल पूछें।'
          : 'Didn\'t understand. I can help you find loads, view your trips, or answer questions.';
    }
    return language == 'hi'
        ? 'समझ नहीं आया। कृपया दोबारा बताएं।'
        : 'I didn\'t understand. Please try again.';
  }
}
