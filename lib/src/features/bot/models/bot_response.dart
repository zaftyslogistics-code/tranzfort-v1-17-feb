// F-15: Input type hint for smart input widgets in bot chat
enum BotInputType {
  text,       // default free text
  city,       // city autocomplete
  material,   // ChoiceChip grid
  truckType,  // ChoiceChip row
  tyres,      // ChoiceChip row
  date,       // date picker
  priceType,  // two-button toggle
  numeric,    // numeric keyboard
}

class BotResponse {
  final String text;
  final String? spokenText;
  final List<String>? suggestions;
  final List<BotAction>? actions;
  BotAction? action;
  final BotInputType inputType;
  final String? intentType; // e.g. 'fallback', 'postLoad' — for LLM routing
  final double? confidence; // intent confidence — for LLM routing

  BotResponse({
    required this.text,
    this.spokenText,
    this.suggestions,
    this.actions,
    this.action,
    this.inputType = BotInputType.text,
    this.intentType,
    this.confidence,
  });

  /// Text to pass to TTS. Uses [spokenText] if set, otherwise strips
  /// emoji, arrows, and bullets from [text].
  String get ttsText {
    if (spokenText != null) return spokenText!;
    return text
        .replaceAll(RegExp(r'[^\x00-\x7F\u0900-\u097F\s\d.,!?%/\-]'), '')
        .replaceAll('\u2192', ' se ')
        .replaceAll('\u2022', ', ')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}

class BotAction {
  final String label;
  final String value;
  final Map<String, dynamic>? payload;

  BotAction({required this.label, required this.value, this.payload});

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    if (payload != null) 'payload': payload,
  };

  factory BotAction.fromJson(Map<String, dynamic> json) => BotAction(
    label: json['label'] as String? ?? '',
    value: json['value'] as String? ?? '',
    payload: json['payload'] as Map<String, dynamic>?,
  );
}

class BotMessage {
  final String text;
  final String? spokenText;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? suggestions;
  final List<BotAction>? actions;
  final BotInputType inputType;

  BotMessage({
    required this.text,
    this.spokenText,
    required this.isUser,
    DateTime? timestamp,
    this.suggestions,
    this.actions,
    this.inputType = BotInputType.text,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Text to pass to TTS. Uses [spokenText] if set, otherwise strips
  /// emoji, arrows, and bullets from [text].
  String get ttsText {
    if (spokenText != null) return spokenText!;
    return text
        .replaceAll(RegExp(r'[^\x00-\x7F\u0900-\u097F\s\d.,!?%/\-]'), '')
        .replaceAll('\u2192', ' se ')
        .replaceAll('\u2022', ', ')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    if (spokenText != null) 'spokenText': spokenText,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    if (suggestions != null) 'suggestions': suggestions,
    if (actions != null)
      'actions': actions!.map((a) => a.toJson()).toList(),
    'inputType': inputType.name,
  };

  factory BotMessage.fromJson(Map<String, dynamic> json) {
    DateTime? ts;
    final tsStr = json['timestamp'] as String?;
    if (tsStr != null) ts = DateTime.tryParse(tsStr);

    BotInputType inputType = BotInputType.text;
    final inputTypeStr = json['inputType'] as String?;
    if (inputTypeStr != null) {
      inputType = BotInputType.values.firstWhere(
        (e) => e.name == inputTypeStr,
        orElse: () => BotInputType.text,
      );
    }

    return BotMessage(
      text: json['text'] as String? ?? '',
      spokenText: json['spokenText'] as String?,
      isUser: json['isUser'] as bool? ?? false,
      timestamp: ts,
      suggestions: (json['suggestions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      actions: (json['actions'] as List<dynamic>?)
          ?.map((e) => BotAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      inputType: inputType,
    );
  }
}
