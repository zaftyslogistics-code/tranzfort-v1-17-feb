import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/config/supabase_config.dart';

/// Simple test to verify Google Places API key is configured
void main() {
  test('Google Places API key should be configured in SupabaseConfig', () {
    final apiKey = SupabaseConfig.googlePlacesApiKey;

    print('=== Google Places API Key Test ===');
    print('API Key loaded: ${apiKey.isNotEmpty ? "YES" : "NO"}');
    print('API Key length: ${apiKey.length} characters');
    print('Starts with: ${apiKey.length >= 8 ? apiKey.substring(0, 8) : apiKey}...');
    print('================================');

    expect(apiKey.isNotEmpty, true, reason: 'API key should not be empty');
    expect(apiKey.length, greaterThan(20), reason: 'API key should be at least 20 characters');
  });
}
