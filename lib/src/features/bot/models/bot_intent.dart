enum BotIntentType {
  postLoad,
  findLoads,
  myLoads,
  myTrips,
  checkStatus,
  repeatLoad,
  navigateTo,
  faqHowToPost,
  faqHowToVerify,
  faqPricing,
  faqSupport,
  manageFleet,
  tripAction,
  uploadLr,
  uploadPod,
  bookLoad,
  superLoad,
  greeting,
  thanks,
  fallback,
}

class BotIntent {
  final BotIntentType type;
  final double confidence;
  final Map<String, dynamic> slots;

  BotIntent({
    required this.type,
    required this.confidence,
    this.slots = const {},
  });

  // B6-FIX: Raised from 0.3 to 0.5 to reduce false-positive intent triggers
  bool get isHighConfidence => confidence >= 0.5;
}

class Slot {
  final String name;
  final String? value;
  final bool isRequired;

  Slot({required this.name, this.value, this.isRequired = true});

  bool get isFilled => value != null && value!.isNotEmpty;
}
