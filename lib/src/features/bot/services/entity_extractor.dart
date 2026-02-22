import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/constants/load_constants.dart';

class EntityExtractor {
  Map<String, dynamic> _entitiesData = {};
  bool _isLoaded = false;

  /// All canonical city names from indian_locations.json + aliases
  List<String> _locationCities = [];
  Map<String, String> _locationAliasMap = {}; // alias → canonical

  /// Pincode index: pincode → "Name, District, State"
  final Map<String, String> _pincodeMap = {}; // pincode → canonical city name
  bool _pincodeIndexLoaded = false;

  Future<void> loadEntities() async {
    if (_isLoaded) return;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/bot/entities.json');
      _entitiesData = json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      _entitiesData = _defaultEntities;
    }

    // Load cities from indian_locations.json for cross-checking
    try {
      final locJson =
          await rootBundle.loadString('assets/data/indian_locations.json');
      final locData = json.decode(locJson) as Map<String, dynamic>;
      final locations = locData['locations'] as List<dynamic>;
      _locationCities = [];
      _locationAliasMap = {};
      for (final loc in locations) {
        final name = loc['name'] as String;
        _locationCities.add(name);
        _locationAliasMap[name.toLowerCase()] = name;
        final aliases = loc['aliases'] as List<dynamic>?;
        if (aliases != null) {
          for (final a in aliases) {
            _locationAliasMap[a.toString().toLowerCase()] = name;
          }
        }
      }
    } catch (_) {
      _locationCities = _defaultCities;
    }

    _isLoaded = true;
  }

  /// Lazy-load pincode index (called only when a 6-digit number is detected).
  Future<void> _ensurePincodeIndex() async {
    if (_pincodeIndexLoaded) return;
    _pincodeIndexLoaded = true;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/pincode_index.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final entries = data['data'] as List<dynamic>;
      // fields: [name, pincode, district, state, lat, lng]
      for (final e in entries) {
        final arr = e as List<dynamic>;
        final pincode = arr[1] as String;
        final name = arr[0] as String;
        if (!_pincodeMap.containsKey(pincode)) {
          _pincodeMap[pincode] = name;
        }
      }
    } catch (_) {
      // pincode_index.json not available — silently ignore
    }
  }

  /// Resolve a 6-digit pincode to a city/locality name.
  /// Returns null if not found.
  Future<String?> resolvePincode(String pincode) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pincode)) return null;
    await _ensurePincodeIndex();
    return _pincodeMap[pincode];
  }

  /// Validate and resolve a raw city name against indian_locations.json.
  /// Returns the canonical city name if found, or null if no match.
  String? resolveCity(String rawInput) {
    final q = rawInput.trim().toLowerCase();
    if (q.isEmpty) return null;

    // 0. 6-digit pincode — resolve synchronously from already-loaded map
    if (RegExp(r'^\d{6}$').hasMatch(q) && _pincodeMap.containsKey(q)) {
      return _pincodeMap[q];
    }

    // 1. Exact match in location alias map
    if (_locationAliasMap.containsKey(q)) return _locationAliasMap[q];

    // 2. Check hardcoded city aliases
    for (final entry in _cityAliases.entries) {
      if (entry.key.toLowerCase() == q) return entry.value;
    }

    // 3. Prefix match (e.g. "mum" → "Mumbai")
    for (final entry in _locationAliasMap.entries) {
      if (entry.key.startsWith(q) && q.length >= 3) return entry.value;
    }

    // 4. Fuzzy Levenshtein match
    // Tighten threshold based on query length to prevent false positives:
    //   - 3-4 chars: distance ≤ 1 (near-exact only)
    //   - 5-7 chars: distance ≤ 2
    //   - 8+ chars:  distance ≤ 3
    final maxDist = q.length <= 4 ? 2 : q.length <= 7 ? 3 : 4;
    String? bestMatch;
    int bestDist = maxDist;
    for (final entry in _locationAliasMap.entries) {
      if ((entry.key.length - q.length).abs() > 3) continue;
      final dist = _levenshtein(q, entry.key);
      if (dist < bestDist) {
        bestDist = dist;
        bestMatch = entry.value;
      }
    }
    return bestMatch;
  }

  Map<String, String?> extract(
    String message,
    String language, {
    Map<String, String?> existingSlots = const {},
  }) {
    final result = <String, String?>{};
    final lowerMessage = message.toLowerCase().trim();

    // If message contains a 6-digit number, trigger pincode index load (fire-and-forget)
    if (RegExp(r'\b\d{6}\b').hasMatch(lowerMessage)) {
      _ensurePincodeIndex();
    }

    // Extract cities — pass existing slots so we fill the right one
    _extractCities(lowerMessage, result, existingSlots);

    // Extract materials
    _extractMaterials(lowerMessage, result);

    // Extract weight
    _extractWeight(lowerMessage, result);

    // Extract truck types
    _extractTruckTypes(lowerMessage, result);

    // Extract tyres
    _extractTyres(lowerMessage, result);

    // Extract price
    _extractPrice(lowerMessage, result);

    // Extract pickup date
    _extractPickupDate(lowerMessage, result);

    return result;
  }

  /// P0-4 / P1-4: Targeted extraction — only run the extractor for the
  /// specific slot being filled. Prevents false cross-slot matches.
  Map<String, String?> extractForSlot(
    String message,
    String language,
    String slotName, {
    Map<String, String?> existingSlots = const {},
  }) {
    final result = <String, String?>{};
    final lowerMessage = message.toLowerCase().trim();

    switch (slotName) {
      case 'origin':
      case 'destination':
        _extractCities(lowerMessage, result, existingSlots);
        break;
      case 'material':
        _extractMaterials(lowerMessage, result);
        break;
      case 'weight':
        _extractWeight(lowerMessage, result);
        break;
      case 'price':
        _extractPrice(lowerMessage, result);
        break;
      case 'truck_type':
        _extractTruckTypes(lowerMessage, result);
        break;
      case 'tyres':
        _extractTyres(lowerMessage, result);
        break;
      case 'pickup_date':
        _extractPickupDate(lowerMessage, result);
        break;
      case 'price_type':
        // Handled by raw input fallback in bot service
        if (lowerMessage.contains('negotiable') || lowerMessage.contains('nego')) {
          result['price_type'] = 'Negotiable';
        } else if (lowerMessage.contains('fixed') || lowerMessage.contains('fix')) {
          result['price_type'] = 'Fixed';
        }
        break;
      case 'advance_percentage':
        // Extract percentage number
        final pctMatch = RegExp(r'(\d+)\s*%?').firstMatch(lowerMessage);
        if (pctMatch != null) {
          final val = int.tryParse(pctMatch.group(1) ?? '');
          if (val != null && val >= 0 && val <= 100) {
            result['advance_percentage'] = val.toString();
          }
        }
        break;
      case 'search_truck_type':
        _extractTruckTypes(lowerMessage, result);
        if (result.containsKey('truck_type')) {
          result['search_truck_type'] = result.remove('truck_type');
        }
        break;
      case 'search_material':
        _extractMaterials(lowerMessage, result);
        if (result.containsKey('material')) {
          result['search_material'] = result.remove('material');
        }
        break;
      case 'notes':
        // Free text — handled by raw input fallback in bot service
        break;
    }
    return result;
  }

  // ── Hindi number word parsing ──────────────────────────────────────────
  static final Map<String, double> _hindiNumbers = {
    'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'panch': 5,
    'chhe': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    'gyarah': 11, 'barah': 12, 'terah': 13, 'chaudah': 14, 'pandrah': 15,
    'solah': 16, 'satrah': 17, 'atharah': 18, 'unnis': 19,
    'bees': 20, 'ikkis': 21, 'bais': 22, 'teis': 23, 'chaubis': 24,
    'pacchis': 25, 'chhabbis': 26, 'sattais': 27, 'attais': 28, 'untees': 29,
    'tees': 30, 'ikattees': 31, 'battees': 32, 'paintees': 35,
    'chalees': 40, 'paintalis': 45,
    'pachaas': 50, 'pachpan': 55,
    'saath': 60, 'painsath': 65,
    'sattar': 70, 'pachattar': 75,
    'assi': 80, 'pachaasi': 85,
    'nabbe': 90, 'pachaanbe': 95,
    'sau': 100, 'hazaar': 1000, 'hazar': 1000, 'lakh': 100000, 'lac': 100000,
  };

  /// Parse Hindi number words from text. Returns null if no Hindi number found.
  /// Supports compound forms: "do sau" = 200, "pacchis hazaar" = 25000
  static double? parseHindiNumber(String text) {
    final words = text.toLowerCase().trim().split(RegExp(r'[\s,]+'));
    if (words.isEmpty) return null;

    double total = 0;
    double current = 0;
    bool found = false;

    for (final word in words) {
      final val = _hindiNumbers[word];
      if (val == null) continue;
      found = true;

      if (val >= 100) {
        // Multiplier: "do sau" = 2 * 100, "teen hazaar" = 3 * 1000
        if (current == 0) current = 1;
        if (val >= 1000 && current > 0) {
          total += current * val;
          current = 0;
        } else {
          current *= val;
        }
      } else {
        current += val;
      }
    }
    total += current;

    return found && total > 0 ? total : null;
  }

  /// Convert an integer to spoken Hindi words (for TTS confirmations).
  /// Covers 1–99,999. Returns the digit string for values outside range.
  static String toHindiWords(int n) {
    if (n <= 0) return n.toString();
    const ones = [
      '', 'ek', 'do', 'teen', 'char', 'paanch', 'chhe', 'saat', 'aath', 'nau',
      'das', 'gyarah', 'barah', 'terah', 'chaudah', 'pandrah', 'solah', 'satrah',
      'atharah', 'unnis', 'bees', 'ikkis', 'bais', 'teis', 'chaubis', 'pachees',
      'chhabbis', 'sattais', 'attais', 'untees', 'tees', 'ikattees', 'battees',
      'taintees', 'chautees', 'paintees', 'chhattees', 'saintees', 'artees',
      'untaalees', 'chaalees', 'iktalees', 'bayalees', 'tiyalees', 'chauvalees',
      'paintaalees', 'chhiyalees', 'saintaalees', 'artaalees', 'unchaas', 'pachaas',
      'ikyaavan', 'baavan', 'tirpan', 'chauvan', 'pachpan', 'chhappan', 'sattavan',
      'atthaavan', 'unsath', 'saath', 'iksath', 'baasath', 'tirsath', 'chausath',
      'painsath', 'chhiyasath', 'sarsath', 'arsath', 'unhattar', 'sattar',
      'ikhattar', 'bahattar', 'tihattar', 'chauhattar', 'pachhattar', 'chhihattar',
      'satattar', 'athattar', 'unaasi', 'assi', 'ikyaasi', 'bayaasi', 'tiraasi',
      'chaurasi', 'pachaasi', 'chhiyaasi', 'sataasi', 'athaasi', 'nawaasi',
      'nabbe', 'ikyaanbe', 'baanbe', 'tiranbe', 'chauranbe', 'pachaanbe',
      'chhiyanbe', 'sattanbe', 'atthanbe', 'ninyaanbe',
    ];
    if (n <= 99) return ones[n];
    if (n < 1000) {
      final h = n ~/ 100;
      final r = n % 100;
      final hWord = '${ones[h]} sau';
      return r == 0 ? hWord : '$hWord ${ones[r]}';
    }
    if (n < 100000) {
      final th = n ~/ 1000;
      final r = n % 1000;
      final thWord = th <= 99 ? '${ones[th]} hazaar' : '${toHindiWords(th)} hazaar';
      if (r == 0) return thWord;
      if (r < 100) return '$thWord ${ones[r]}';
      return '$thWord ${toHindiWords(r)}';
    }
    return n.toString();
  }

  void _extractCities(
      String message, Map<String, String?> result, Map<String, String?> existingSlots) {
    // Check what's already filled so we fill the NEXT empty slot
    final hasOrigin = (existingSlots['origin'] ?? '').isNotEmpty;
    final hasDest = (existingSlots['destination'] ?? '').isNotEmpty;

    // Pincode extraction: detect 6-digit numbers and resolve from loaded map
    if (_pincodeIndexLoaded && _pincodeMap.isNotEmpty) {
      final pincodeRegex = RegExp(r'\b(\d{6})\b');
      final pincodeMatches = pincodeRegex.allMatches(message);
      for (final match in pincodeMatches) {
        final pincode = match.group(1)!;
        final resolved = _pincodeMap[pincode];
        if (resolved != null) {
          final idx = match.start;
          _assignCity(result, resolved, idx, message,
              const ['se', 'from', 'starting', 'origin', 'pickup', 'loading'],
              const ['to', 'tak', 'destination', 'ke liye', 'deliver', 'unloading', 'drop'],
              hasOrigin, hasDest, existingSlots);
        }
      }
      // If both slots filled by pincodes, return early
      if (result.containsKey('origin') && result.containsKey('destination')) return;
    }

    final originIndicators = [
      'se', 'from', 'starting', 'origin', 'pickup', 'loading',
      'se load', 'se bhejna', 'se bhejo',
    ];
    final destIndicators = [
      'to', 'tak', 'destination', 'ke liye', 'deliver', 'unloading',
      'drop', 'pahunchana', 'bhejni hai', 'jaana hai', 'jana hai',
    ];

    // Build alias → canonical map from indian_locations.json + hardcoded aliases
    final allNames = <String, String>{..._locationAliasMap};
    for (final entry in _cityAliases.entries) {
      allNames[entry.key.toLowerCase()] = entry.value;
    }

    // Sort by length descending to match longer names first
    final sortedNames = allNames.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final name in sortedNames) {
      if (!message.contains(name)) continue;
      final canonical = allNames[name]!;
      final cityIndex = message.indexOf(name);
      _assignCity(result, canonical, cityIndex, message,
          originIndicators, destIndicators, hasOrigin, hasDest, existingSlots);
    }

    // LOC-049: POI-aware extraction (e.g., "midc nagpur", "icd delhi")
    final poiPattern = RegExp(
      r'\b(?:midc|sez|icd|port|mandi|transport\s+nagar|industrial\s+area|depot|hub)\s+([a-z][a-z\s]{2,40})',
    );
    for (final match in poiPattern.allMatches(message)) {
      final rawCity = (match.group(1) ?? '').trim();
      if (rawCity.isEmpty) continue;

      // Try longer phrase first, then last token as fallback
      String? canonical = resolveCity(rawCity);
      if (canonical == null) {
        final parts = rawCity.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          canonical = resolveCity(parts.last);
        }
      }

      if (canonical != null) {
        _assignCity(result, canonical, match.start, message, originIndicators,
            destIndicators, hasOrigin, hasDest, existingSlots);
      }
    }

    // LOC-047: Compound location parsing (e.g., "badnera nagpur")
    if (!result.containsKey('origin') || !result.containsKey('destination')) {
      final words = message.split(RegExp(r'[\s,;]+'));
      if (words.length >= 2) {
        for (var i = 0; i < words.length - 1; i++) {
          final second = words[i + 1].trim();
          if (second.length < 3) continue;

          final canonical = resolveCity(second);
          if (canonical == null) continue;

          final pairStart = message.indexOf('${words[i]} $second');
          final idx = pairStart >= 0 ? pairStart : message.indexOf(second);
          _assignCity(result, canonical, idx, message, originIndicators,
              destIndicators, hasOrigin, hasDest, existingSlots);

          if (result.containsKey('origin') && result.containsKey('destination')) {
            break;
          }
        }
      }
    }

    // Fuzzy matching: if no cities found yet, try Levenshtein on each word
    if (!result.containsKey('origin') && !result.containsKey('destination')) {
      final words = message.split(RegExp(r'[\s,;]+'));
      for (final word in words) {
        if (word.length < 3) continue;
        String? bestMatch;
        final threshold = word.length <= 4 ? 2 : word.length <= 7 ? 3 : 4;
        int bestDist = threshold;
        for (final name in allNames.keys) {
          if ((name.length - word.length).abs() > 2) continue;
          final dist = _levenshtein(word, name);
          if (dist < bestDist) {
            bestDist = dist;
            bestMatch = allNames[name];
          }
        }
        if (bestMatch != null) {
          final cityIndex = message.indexOf(word);
          _assignCity(result, bestMatch, cityIndex, message,
              originIndicators, destIndicators, hasOrigin, hasDest, existingSlots);
          if (result.containsKey('origin') && result.containsKey('destination')) break;
        }
      }
    }
  }

  void _assignCity(
    Map<String, String?> result,
    String canonical,
    int cityIndex,
    String message,
    List<String> originIndicators,
    List<String> destIndicators,
    bool hasOrigin,
    bool hasDest,
    Map<String, String?> existingSlots,
  ) {

      bool isOrigin = false;
      for (final indicator in originIndicators) {
        final idx = message.indexOf(indicator);
        if (idx != -1 && idx < cityIndex && (cityIndex - idx) < 35) {
          isOrigin = true;
          break;
        }
      }

      bool isDest = false;
      for (final indicator in destIndicators) {
        final idx = message.indexOf(indicator);
        if (idx != -1 && idx < cityIndex && (cityIndex - idx) < 35) {
          isDest = true;
          break;
        }
      }

    if (isOrigin && !result.containsKey('origin')) {
      result['origin'] = canonical;
    } else if (isDest && !result.containsKey('destination')) {
      result['destination'] = canonical;
    } else if (!hasOrigin && !result.containsKey('origin')) {
      result['origin'] = canonical;
    } else if (!hasDest && !result.containsKey('destination') &&
        canonical != (existingSlots['origin'] ?? '') &&
        canonical != (result['origin'] ?? '')) {
      result['destination'] = canonical;
    } else if (hasOrigin && !hasDest && !result.containsKey('destination')) {
      result['destination'] = canonical;
    }
  }

  /// Levenshtein edit distance between two strings.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> prev = List.generate(b.length + 1, (i) => i);
    List<int> curr = List.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[b.length];
  }

  void _extractMaterials(String message, Map<String, String?> result) {
    final materials = (_entitiesData['materials'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        _defaultMaterials;

    // Check canonical names
    for (final material in materials) {
      if (message.contains(material.toLowerCase())) {
        result['material'] = material;
        return;
      }
    }

    // Check Hindi/Hinglish aliases
    for (final entry in _materialAliases.entries) {
      if (message.contains(entry.key.toLowerCase())) {
        result['material'] = entry.value;
        return;
      }
    }
  }

  void _extractWeight(String message, Map<String, String?> result) {
    // Normalize commas in numbers: "1,500" → "1500"
    final normalized = message.replaceAll(RegExp(r'(\d),(\d)'), r'$1$2');

    // P0-3: Match range format: "25-30 ton" → take first number
    final rangeWithUnit = RegExp(
        r'(\d+(?:\.\d+)?)\s*[-–to]+\s*\d+(?:\.\d+)?\s*(?:mt\b|metric\s*ton|ton|tonne|tonnes|t\b|kg|kgs|kilogram|quintal|quintals|क्विंटल|टन)');
    final matchRange = rangeWithUnit.firstMatch(normalized);
    if (matchRange != null) {
      result['weight'] = matchRange.group(1);
      return;
    }

    // Match with unit — handle tonnes, MT, kg, quintal
    final weightWithUnit = RegExp(
        r'(\d+(?:\.\d+)?)\s*(?:mt\b|metric\s*ton|ton|tonne|tonnes|t\b|kg|kgs|kilogram|quintal|quintals|क्विंटल|टन)');
    final matchUnit = weightWithUnit.firstMatch(normalized);
    if (matchUnit != null) {
      final raw = double.tryParse(matchUnit.group(1)!) ?? 0;
      final unitStr = normalized.substring(matchUnit.start, matchUnit.end).toLowerCase();
      double tonnes = raw;
      if (unitStr.contains('kg') || unitStr.contains('kilogram')) {
        tonnes = raw / 1000;
      } else if (unitStr.contains('quintal') || unitStr.contains('क्विंटल')) {
        tonnes = raw / 10;
      }
      result['weight'] = tonnes.toStringAsFixed(tonnes == tonnes.roundToDouble() ? 0 : 1);
      return;
    }

    // P0-3: Match bare number (relaxed — works for any message length during slot-filling)
    final bareNumber = RegExp(r'(\d+(?:\.\d+)?)');
    final matchBare = bareNumber.firstMatch(normalized.trim());
    if (matchBare != null) {
      result['weight'] = matchBare.group(1);
      return;
    }

    // P0-3: Try Hindi number words: "pacchis ton", "do sau quintal"
    final hindiVal = parseHindiNumber(normalized);
    if (hindiVal != null && hindiVal > 0 && hindiVal <= 10000) {
      // Check for unit to determine conversion
      if (normalized.contains('quintal') || normalized.contains('क्विंटल')) {
        final tonnes = hindiVal / 10;
        result['weight'] = tonnes.toStringAsFixed(tonnes == tonnes.roundToDouble() ? 0 : 1);
      } else if (normalized.contains('kg') || normalized.contains('kilogram')) {
        final tonnes = hindiVal / 1000;
        result['weight'] = tonnes.toStringAsFixed(tonnes == tonnes.roundToDouble() ? 0 : 1);
      } else {
        result['weight'] = hindiVal.toStringAsFixed(hindiVal == hindiVal.roundToDouble() ? 0 : 1);
      }
    }
  }

  void _extractTruckTypes(String message, Map<String, String?> result) {
    final truckTypes = (_entitiesData['truck_types'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        _defaultTruckTypes;

    for (final type in truckTypes) {
      if (message.contains(type.toLowerCase())) {
        result['truck_type'] = type;
        return;
      }
    }

    // Hindi/Hinglish aliases
    for (final entry in _truckTypeAliases.entries) {
      if (message.contains(entry.key.toLowerCase())) {
        result['truck_type'] = entry.value;
        return;
      }
    }
  }

  void _extractTyres(String message, Map<String, String?> result) {
    // Match "any" for tyres
    if (message.contains('any') && !result.containsKey('tyres')) {
      // Only set if context suggests tyres (handled by slot-filling order)
      return;
    }

    // Match tyre counts: "6 tyre", "10 wheeler", "12 chakka", etc.
    final tyrePatterns = [
      RegExp(r'(\d+)\s*(?:tyre|tyres|tire|tires|wheeler|wheel|chakka|chakke|पहिया|पहिये)'),
      RegExp(r'(?:tyre|tyres|tire|wheeler)\s*(\d+)'),
    ];

    for (final pattern in tyrePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final count = int.tryParse(match.group(1) ?? '');
        if (count != null && [6, 10, 12, 14, 16, 18, 22].contains(count)) {
          result['tyres'] = count.toString();
          return;
        }
      }
    }
  }

  void _extractPrice(String message, Map<String, String?> result) {
    // Normalize commas: "2,500" → "2500"
    final normalized = message.replaceAll(RegExp(r'(\d),(\d)'), r'$1$2');

    // Match "₹2500", "rs 2500", "2500 rupees", "2500/ton", "2500 per ton"
    final pricePatterns = [
      RegExp(r'[₹rs\.]+\s*(\d+(?:\.\d+)?)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:rupees|rupee|rs|per\s*ton|/ton|/tonne|प्रति\s*टन|रुपये|रुपया)'),
      RegExp(r'rate\s*(\d+(?:\.\d+)?)'),
      RegExp(r'price\s*(\d+(?:\.\d+)?)'),
      RegExp(r'keemat\s*(\d+(?:\.\d+)?)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:rate|keemat)'),
    ];

    for (final pattern in pricePatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final value = match.group(1);
        if (value != null) {
          final parsed = double.tryParse(value);
          // Only accept reasonable prices (₹1 to ₹100000)
          if (parsed != null && parsed >= 1 && parsed <= 100000) {
            result['price'] = value;
            return;
          }
        }
      }
    }

    // P0-3: Match bare number (during slot-filling, any number is likely a price)
    final bareNumber = RegExp(r'(\d+(?:\.\d+)?)');
    final matchBare = bareNumber.firstMatch(normalized.trim());
    if (matchBare != null) {
      final parsed = double.tryParse(matchBare.group(1) ?? '');
      if (parsed != null && parsed >= 1 && parsed <= 100000) {
        result['price'] = matchBare.group(1);
        return;
      }
    }

    // P0-3: Try Hindi number words for price: "do hazaar", "pacchis sau"
    final hindiVal = parseHindiNumber(normalized);
    if (hindiVal != null && hindiVal >= 1 && hindiVal <= 100000) {
      result['price'] = hindiVal.toStringAsFixed(hindiVal == hindiVal.roundToDouble() ? 0 : 1);
    }
  }

  void _extractPickupDate(String message, Map<String, String?> result) {
    final now = DateTime.now();

    // Hindi/Hinglish date words
    final dateMap = <String, int>{
      'aaj': 0, 'today': 0, 'आज': 0,
      'kal': 1, 'tomorrow': 1, 'कल': 1,
      'parso': 2, 'parson': 2, 'day after': 2, 'परसों': 2,
    };

    for (final entry in dateMap.entries) {
      if (message.contains(entry.key)) {
        final date = now.add(Duration(days: entry.value));
        result['pickup_date'] = date.toIso8601String().split('T').first;
        return;
      }
    }

    // Day names → next occurrence
    final dayNames = {
      'monday': DateTime.monday, 'somvar': DateTime.monday, 'सोमवार': DateTime.monday,
      'tuesday': DateTime.tuesday, 'mangalvar': DateTime.tuesday, 'मंगलवार': DateTime.tuesday,
      'wednesday': DateTime.wednesday, 'budhvar': DateTime.wednesday, 'बुधवार': DateTime.wednesday,
      'thursday': DateTime.thursday, 'guruvar': DateTime.thursday, 'गुरुवार': DateTime.thursday,
      'friday': DateTime.friday, 'shukravar': DateTime.friday, 'शुक्रवार': DateTime.friday,
      'saturday': DateTime.saturday, 'shanivar': DateTime.saturday, 'शनिवार': DateTime.saturday,
      'sunday': DateTime.sunday, 'ravivar': DateTime.sunday, 'रविवार': DateTime.sunday,
    };

    for (final entry in dayNames.entries) {
      if (message.contains(entry.key)) {
        var daysAhead = entry.value - now.weekday;
        if (daysAhead <= 0) daysAhead += 7;
        final date = now.add(Duration(days: daysAhead));
        result['pickup_date'] = date.toIso8601String().split('T').first;
        return;
      }
    }

    // Match explicit date: "25 feb", "25/02", "25-02"
    final dateRegex = RegExp(r'(\d{1,2})[/\-\s]+(\d{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)');
    final dateMatch = dateRegex.firstMatch(message);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1) ?? '');
      final monthStr = dateMatch.group(2) ?? '';
      int? month = int.tryParse(monthStr);
      if (month == null) {
        const months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
        month = months[monthStr.toLowerCase()];
      }
      if (day != null && month != null && day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        var year = now.year;
        final candidate = DateTime(year, month, day);
        if (candidate.isBefore(now)) year++;
        result['pickup_date'] = DateTime(year, month, day).toIso8601String().split('T').first;
      }
    }
  }

  // --- City aliases (Hindi/Hinglish → canonical English) ---
  static const _cityAliases = {
    'bombay': 'Mumbai',
    'bambai': 'Mumbai',
    'mumba': 'Mumbai',
    'dilli': 'Delhi',
    'new delhi': 'Delhi',
    'nai dilli': 'Delhi',
    'nai delhi': 'Delhi',
    'bengaluru': 'Bangalore',
    'bengalore': 'Bangalore',
    'blr': 'Bangalore',
    'calcutta': 'Kolkata',
    'kolkatta': 'Kolkata',
    'madras': 'Chennai',
    'baroda': 'Vadodara',
    'banaras': 'Varanasi',
    'varanasi': 'Varanasi',
    'kashi': 'Varanasi',
    'gurgaon': 'Gurugram',
    'gurugram': 'Gurugram',
    'noida': 'Noida',
    'chandigarh': 'Chandigarh',
    'coimbatore': 'Coimbatore',
    'kovai': 'Coimbatore',
    'vizag': 'Visakhapatnam',
    'visakhapatnam': 'Visakhapatnam',
    'waltair': 'Visakhapatnam',
    'trivandrum': 'Thiruvananthapuram',
    'thiruvananthapuram': 'Thiruvananthapuram',
    'cochin': 'Kochi',
    'kochi': 'Kochi',
    'ernakulam': 'Kochi',
    'mysore': 'Mysuru',
    'mysuru': 'Mysuru',
    'rajkot': 'Rajkot',
    'raipur': 'Raipur',
    'ranchi': 'Ranchi',
    'dehradun': 'Dehradun',
    'dehra dun': 'Dehradun',
    'guwahati': 'Guwahati',
    'gauhati': 'Guwahati',
    'jodhpur': 'Jodhpur',
    'udaipur': 'Udaipur',
    'amritsar': 'Amritsar',
    'jalandhar': 'Jalandhar',
    'faridabad': 'Faridabad',
    'ghaziabad': 'Ghaziabad',
    'meerut': 'Meerut',
    'allahabad': 'Prayagraj',
    'prayagraj': 'Prayagraj',
    'thane': 'Thane',
    'navi mumbai': 'Navi Mumbai',
    // F-28: Missing city aliases
    'poona': 'Pune',
    'puna': 'Pune',
    'paatna': 'Patna',
    'patana': 'Patna',
    'soorat': 'Surat',
    'surat': 'Surat',
    'sourat': 'Surat',
    'mumbai': 'Mumbai',
    'hydrabad': 'Hyderabad',
    'hyd': 'Hyderabad',
    'secundrabad': 'Hyderabad',
    'secunderabad': 'Hyderabad',
    'ahmedabad': 'Ahmedabad',
    'amdavad': 'Ahmedabad',
    'jaipur': 'Jaipur',
    'pinkcity': 'Jaipur',
    'pink city': 'Jaipur',
    'lucknow': 'Lucknow',
    'lko': 'Lucknow',
    'nagpur': 'Nagpur',
    'indore': 'Indore',
    'bhopal': 'Bhopal',
    'ludhiana': 'Ludhiana',
    'agra': 'Agra',
    'nashik': 'Nashik',
    'nasik': 'Nashik',
    'kanpur': 'Kanpur',
    'cawnpore': 'Kanpur',
    'jabalpur': 'Jabalpur',
    'jabbalpur': 'Jabalpur',
    'aurangabad': 'Aurangabad',
    'sambhajinagar': 'Aurangabad',
    'srinagar': 'Srinagar',
    'jammu': 'Jammu',
    'shimla': 'Shimla',
    'manali': 'Manali',
    'kota': 'Kota',
    'ajmer': 'Ajmer',
    'bikaner': 'Bikaner',
    'bhilai': 'Bhilai',
    'durg': 'Durg',
    'bilaspur': 'Bilaspur',
    'bhubaneswar': 'Bhubaneswar',
    'bbsr': 'Bhubaneswar',
    'cuttack': 'Cuttack',
    'siliguri': 'Siliguri',
    'asansol': 'Asansol',
    'durgapur': 'Durgapur',
    'mangalore': 'Mangaluru',
    'mangaluru': 'Mangaluru',
    'hubli': 'Hubballi',
    'hubballi': 'Hubballi',
    'belgaum': 'Belagavi',
    'belagavi': 'Belagavi',
    'tirupati': 'Tirupati',
    'vijayawada': 'Vijayawada',
    'guntur': 'Guntur',
    'madurai': 'Madurai',
    'trichy': 'Tiruchirappalli',
    'tiruchirappalli': 'Tiruchirappalli',
    'salem': 'Salem',
    'tirunelveli': 'Tirunelveli',
    'vellore': 'Vellore',
  };

  // --- Material aliases (Hindi/Hinglish → canonical English) ---
  static const _materialAliases = {
    'loha': 'Steel',
    'ispat': 'Steel',
    'sariya': 'Steel',
    'lohiya': 'Steel',
    'cement': 'Cement',
    'simant': 'Cement',
    'siment': 'Cement',
    'koyla': 'Coal',
    'koyala': 'Coal',
    'coal': 'Coal',
    'ret': 'Sand',
    'balu': 'Sand',
    'sand': 'Sand',
    'bajri': 'Gravel',
    'gitti': 'Gravel',
    'gravel': 'Gravel',
    'lakdi': 'Timber',
    'wood': 'Timber',
    'timber': 'Timber',
    'kapas': 'Cotton',
    'cotton': 'Cotton',
    'chawal': 'Rice',
    'rice': 'Rice',
    'gehun': 'Wheat',
    'wheat': 'Wheat',
    'cheeni': 'Sugar',
    'shakkar': 'Sugar',
    'sugar': 'Sugar',
    'khad': 'Fertilizer',
    'fertilizer': 'Fertilizer',
    'rasayan': 'Chemicals',
    'chemical': 'Chemicals',
    'chemicals': 'Chemicals',
    'samaan': 'Furniture',
    'furniture': 'Furniture',
    'machine': 'Machinery',
    'mashinari': 'Machinery',
    'machinery': 'Machinery',
    'daal': 'Pulses',
    'dal': 'Pulses',
    'pulses': 'Pulses',
    'tel': 'Oil',
    'oil': 'Oil',
    'tiles': 'Tiles',
    'marble': 'Marble',
    'granite': 'Granite',
    'pathar': 'Stone',
    'stone': 'Stone',
    'iron': 'Steel',
    'atta': 'Wheat',
    'flour': 'Wheat',
    // F-29: Missing material aliases
    'eent': 'Bricks',
    'int': 'Bricks',
    'bricks': 'Bricks',
    'brick': 'Bricks',
    'plastic': 'Plastic',
    'plastik': 'Plastic',
    'glass': 'Glass',
    'kaanch': 'Glass',
    'kanch': 'Glass',
    'sheesha': 'Glass',
    'pharma': 'Pharma',
    'medicine': 'Pharma',
    'dawai': 'Pharma',
    'dawa': 'Pharma',
    'pharmaceutical': 'Pharma',
    'spare parts': 'Spare Parts',
    'spares': 'Spare Parts',
    'auto parts': 'Spare Parts',
    'parts': 'Spare Parts',
    'purza': 'Spare Parts',
    'purze': 'Spare Parts',
    'electronics': 'Electronics',
    'electronic': 'Electronics',
    'bijli ka saman': 'Electronics',
    'paint': 'Paint',
    'rang': 'Paint',
    'paints': 'Paint',
    'cloth': 'Textiles',
    'kapda': 'Textiles',
    'textile': 'Textiles',
    'textiles': 'Textiles',
    'garment': 'Textiles',
    'garments': 'Textiles',
    'fruits': 'Fruits',
    'fal': 'Fruits',
    'vegetables': 'Vegetables',
    'sabzi': 'Vegetables',
    'tarkari': 'Vegetables',
    'milk': 'Dairy',
    'doodh': 'Dairy',
    'dairy': 'Dairy',
    'fish': 'Fish',
    'machli': 'Fish',
    'maachli': 'Fish',
  };

  // --- Truck type aliases ---
  static const _truckTypeAliases = {
    'khula': 'Open',
    'open body': 'Open',
    'khuli gaadi': 'Open',
    'container': 'Container',
    'kontainer': 'Container',
    'trailer': 'Trailer',
    'semi trailer': 'Trailer',
    'tanker': 'Tanker',
    'tanki': 'Tanker',
    'chhakda': 'Open',
    'tractor': 'Tractor',
    // F-30: Missing truck type aliases
    'flatbed': 'Open',
    'flat bed': 'Open',
    'lcv': 'LCV',
    'light commercial': 'LCV',
    'light vehicle': 'LCV',
    'chota truck': 'LCV',
    'chhota truck': 'LCV',
    'mini truck': 'LCV',
    'mini gaadi': 'LCV',
    'tata ace': 'LCV',
    'pickup truck': 'LCV',
    'hcv': 'HCV',
    'heavy commercial': 'HCV',
    'heavy vehicle': 'HCV',
    'bada truck': 'HCV',
    'badi gaadi': 'HCV',
    'tipper': 'Tipper',
    'dumper': 'Tipper',
    'hyva': 'Tipper',
    'refrigerated': 'Reefer',
    'reefer': 'Reefer',
    'cold chain': 'Reefer',
    'thanda truck': 'Reefer',
    'low bed': 'Low Bed',
    'lowbed': 'Low Bed',
    'lowboy': 'Low Bed',
    'jcb transport': 'Low Bed',
  };

  static const _defaultCities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
    'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow',
    'Nagpur', 'Indore', 'Surat', 'Bhopal', 'Patna',
    'Vadodara', 'Ludhiana', 'Agra', 'Nashik', 'Kanpur',
    'Varanasi', 'Gurugram', 'Noida', 'Chandigarh', 'Coimbatore',
    'Visakhapatnam', 'Kochi', 'Rajkot', 'Raipur', 'Ranchi',
    'Dehradun', 'Guwahati', 'Jodhpur', 'Udaipur', 'Amritsar',
    'Faridabad', 'Ghaziabad', 'Meerut', 'Prayagraj', 'Thane',
  ];

  static const _defaultMaterials = LoadConstants.materials;

  static const _defaultTruckTypes = LoadConstants.truckTypes;

  static final Map<String, dynamic> _defaultEntities = {
    'cities': _defaultCities,
    'materials': _defaultMaterials,
    'truck_types': _defaultTruckTypes,
  };
}
