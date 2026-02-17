import 'package:supabase_flutter/supabase_flutter.dart';

class SchemaSmokeCheckException implements Exception {
  final List<String> failures;

  const SchemaSmokeCheckException(this.failures);

  @override
  String toString() {
    return 'Schema smoke check failed for: ${failures.join(', ')}';
  }
}

class SchemaSmokeCheckService {
  final SupabaseClient _supabase;

  SchemaSmokeCheckService(this._supabase);

  static const List<String> _requiredUserRelations = <String>[
    'profiles',
    'public_profiles',
    'conversations',
    'messages',
    'support_ticket_messages',
  ];

  Future<void> verifyUserRelations() async {
    final failures = <String>[];

    for (final relation in _requiredUserRelations) {
      final failure = await _probeRelation(relation);
      if (failure != null) {
        failures.add(failure);
      }
    }

    if (failures.isNotEmpty) {
      throw SchemaSmokeCheckException(failures);
    }
  }

  Future<String?> _probeRelation(String relation) async {
    try {
      await _supabase.from(relation).select('id').limit(1);
      return null;
    } on PostgrestException catch (error) {
      final code = error.code?.trim().isNotEmpty == true ? error.code : 'unknown';
      return '$relation [$code]: ${error.message}';
    } catch (error) {
      return '$relation [unexpected]: $error';
    }
  }
}
