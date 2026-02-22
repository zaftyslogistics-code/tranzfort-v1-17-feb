import 'package:supabase_flutter/supabase_flutter.dart';

/// Category options for user-contributed POIs.
enum PoiCategory {
  dhaba,
  fuelStation,
  loadingPoint,
  unloadingPoint,
  truckParking,
  warehouse,
  factory,
  tyreShop,
  mechanic,
  restArea,
  transportNagar,
  other;

  String get label {
    switch (this) {
      case PoiCategory.dhaba:
        return 'Dhaba / Restaurant';
      case PoiCategory.fuelStation:
        return 'Fuel Station';
      case PoiCategory.loadingPoint:
        return 'Loading Point';
      case PoiCategory.unloadingPoint:
        return 'Unloading Point';
      case PoiCategory.truckParking:
        return 'Truck Parking';
      case PoiCategory.warehouse:
        return 'Warehouse / Godown';
      case PoiCategory.factory:
        return 'Factory / Plant';
      case PoiCategory.tyreShop:
        return 'Tyre Shop';
      case PoiCategory.mechanic:
        return 'Mechanic / Workshop';
      case PoiCategory.restArea:
        return 'Rest Area';
      case PoiCategory.transportNagar:
        return 'Transport Nagar';
      case PoiCategory.other:
        return 'Other';
    }
  }

  String get dbValue {
    switch (this) {
      case PoiCategory.dhaba:
        return 'dhaba';
      case PoiCategory.fuelStation:
        return 'fuel_station';
      case PoiCategory.loadingPoint:
        return 'loading_point';
      case PoiCategory.unloadingPoint:
        return 'unloading_point';
      case PoiCategory.truckParking:
        return 'truck_parking';
      case PoiCategory.warehouse:
        return 'warehouse';
      case PoiCategory.factory:
        return 'factory';
      case PoiCategory.tyreShop:
        return 'tyre_shop';
      case PoiCategory.mechanic:
        return 'mechanic';
      case PoiCategory.restArea:
        return 'rest_area';
      case PoiCategory.transportNagar:
        return 'transport_nagar';
      case PoiCategory.other:
        return 'other';
    }
  }

  static PoiCategory fromDbValue(String v) {
    return PoiCategory.values.firstWhere(
      (e) => e.dbValue == v,
      orElse: () => PoiCategory.other,
    );
  }
}

class LocationSuggestion {
  final String? id;
  final String name;
  final PoiCategory category;
  final double lat;
  final double lng;
  final String? address;
  final String? pincode;
  final String? district;
  final String? state;
  final String? phone;
  final List<String> photos;
  final String? notes;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime? createdAt;

  const LocationSuggestion({
    this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.address,
    this.pincode,
    this.district,
    this.state,
    this.phone,
    this.photos = const [],
    this.notes,
    this.status = 'pending',
    this.createdAt,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      category: PoiCategory.fromDbValue(json['category'] as String? ?? 'other'),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
      pincode: json['pincode'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'suggested_by': userId,
        'name': name,
        'category': category.dbValue,
        'lat': lat,
        'lng': lng,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
        if (district != null && district!.isNotEmpty) 'district': district,
        if (state != null && state!.isNotEmpty) 'state': state,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (photos.isNotEmpty) 'photos': photos,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'status': 'pending',
      };
}

class LocationSuggestionsService {
  final SupabaseClient _supabase;

  LocationSuggestionsService(this._supabase);

  /// Submit a new location suggestion from the current user.
  Future<LocationSuggestion> submit(
      String userId, LocationSuggestion suggestion) async {
    final response = await _supabase
        .from('location_suggestions')
        .insert(suggestion.toInsertJson(userId))
        .select()
        .single();
    return LocationSuggestion.fromJson(response);
  }

  /// Get all suggestions submitted by the current user.
  Future<List<LocationSuggestion>> getMySuggestions(String userId) async {
    final response = await _supabase
        .from('location_suggestions')
        .select()
        .eq('suggested_by', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => LocationSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
