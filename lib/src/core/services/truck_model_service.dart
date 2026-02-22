import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/truck_model_spec.dart';

/// Service for fetching and searching the master truck models catalog
/// from the `truck_models` Supabase table.
class TruckModelService {
  final SupabaseClient _supabase;

  // In-memory cache — loaded once, ~50 rows
  List<TruckModelSpec>? _cache;
  Map<String, List<TruckModelSpec>>? _byMake;

  TruckModelService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Load all active truck models. Cached after first call.
  Future<List<TruckModelSpec>> getAll() async {
    if (_cache != null) return _cache!;

    final response = await _supabase
        .from('truck_models')
        .select()
        .eq('is_active', true)
        .order('make')
        .order('model');

    _cache = (response as List)
        .map((row) => TruckModelSpec.fromJson(row as Map<String, dynamic>))
        .toList();

    // Build make index
    _byMake = {};
    for (final spec in _cache!) {
      _byMake!.putIfAbsent(spec.make, () => []).add(spec);
    }

    return _cache!;
  }

  /// Get distinct makes (e.g., ['Ashok Leyland', 'BharatBenz', 'Eicher', ...])
  Future<List<String>> getMakes() async {
    final all = await getAll();
    final makes = all.map((s) => s.make).toSet().toList()..sort();
    return makes;
  }

  /// Get models for a specific make
  Future<List<TruckModelSpec>> getModelsForMake(String make) async {
    await getAll();
    return _byMake?[make] ?? [];
  }

  /// Search models by query string (matches make, model, or variant)
  Future<List<TruckModelSpec>> search(String query) async {
    final all = await getAll();
    if (query.trim().isEmpty) return all;

    final q = query.toLowerCase();
    return all.where((spec) {
      return spec.make.toLowerCase().contains(q) ||
          spec.model.toLowerCase().contains(q) ||
          (spec.variant?.toLowerCase().contains(q) ?? false) ||
          spec.displayName.toLowerCase().contains(q);
    }).toList();
  }

  /// Get a single model by ID
  Future<TruckModelSpec?> getById(String id) async {
    final all = await getAll();
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Invalidate cache (e.g., after admin adds a new model)
  void clearCache() {
    _cache = null;
    _byMake = null;
  }
}
