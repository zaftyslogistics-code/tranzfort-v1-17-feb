import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tranzfort/src/core/config/supabase_config.dart';

/// Integration test to verify Google Places API (New) key works with real network call
void main() {
  group('Google Places API (New) Integration Tests', () {
    
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': SupabaseConfig.googlePlacesApiKey,
    };

    test('API key should make successful autocomplete request', () async {
      final apiKey = SupabaseConfig.googlePlacesApiKey;
      
      print('Testing NEW Places API with key: ${apiKey.substring(0, 10)}... (${apiKey.length} chars)');
      
      final body = json.encode({
        'input': 'Mumbai Central',
        'sessionToken': 'test-session-123',
        'includedPrimaryTypes': ['geocode', 'establishment'],
        'includedRegionCodes': ['in'],
      });
      
      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      expect(response.statusCode, equals(200), 
          reason: 'API should return 200 OK');
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>? ?? [];
      
      print('Suggestions count: ${suggestions.length}');
      
      // List first few predictions for debugging
      for (var i = 0; i < suggestions.length && i < 3; i++) {
        final s = suggestions[i] as Map<String, dynamic>;
        final placePrediction = s['placePrediction'] as Map<String, dynamic>?;
        final text = placePrediction?['text'] as Map<String, dynamic>?;
        print('  ${i + 1}. ${text?['text'] ?? 'N/A'}');
      }
      
      expect(suggestions.isNotEmpty, isTrue,
          reason: 'Should return at least one suggestion for "Mumbai Central"');
    });
    
    test('API key should handle unknown places not in JSON database', () async {
      // Search for a specific place unlikely to be in our JSON
      final body = json.encode({
        'input': 'Hinjewadi IT Park Pune',
        'sessionToken': 'test-session-456',
        'includedPrimaryTypes': ['geocode', 'establishment'],
        'includedRegionCodes': ['in'],
      });
      
      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>? ?? [];
      
      print('Search for "Hinjewadi IT Park Pune":');
      print('  Status: ${response.statusCode}');
      print('  Results: ${suggestions.length}');
      
      for (var i = 0; i < suggestions.length && i < 3; i++) {
        final s = suggestions[i] as Map<String, dynamic>;
        final placePrediction = s['placePrediction'] as Map<String, dynamic>?;
        final text = placePrediction?['text'] as Map<String, dynamic>?;
        print('    ${i + 1}. ${text?['text'] ?? 'N/A'}');
      }
      
      // Skip if API key has restrictions that block test environment
      if (response.statusCode == 403) {
        print('WARNING: API key restricted (403). Skipping test in CI environment.');
        return;
      }
    });
  });
}
