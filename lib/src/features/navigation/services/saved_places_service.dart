import 'package:supabase_flutter/supabase_flutter.dart';

class SavedPlace {
  final String? id;
  final String label;
  final String icon;
  final String city;
  final String? state;
  final double? lat;
  final double? lng;
  final String? address;
  final int sortOrder;

  const SavedPlace({
    this.id,
    required this.label,
    this.icon = 'star',
    required this.city,
    this.state,
    this.lat,
    this.lng,
    this.address,
    this.sortOrder = 0,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String?,
        label: json['label'] as String? ?? '',
        icon: json['icon'] as String? ?? 'star',
        city: json['city'] as String? ?? '',
        state: json['state'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        address: json['address'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toInsertJson(String userId) => {
        'user_id': userId,
        'label': label,
        'icon': icon,
        'city': city,
        if (state != null) 'state': state,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (address != null) 'address': address,
        'sort_order': sortOrder,
      };
}

class SavedPlacesService {
  final SupabaseClient _supabase;

  SavedPlacesService(this._supabase);

  Future<List<SavedPlace>> getPlaces(String userId) async {
    final response = await _supabase
        .from('saved_places')
        .select()
        .eq('user_id', userId)
        .order('sort_order')
        .order('created_at');
    return (response as List)
        .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SavedPlace> addPlace(String userId, SavedPlace place) async {
    final response = await _supabase
        .from('saved_places')
        .upsert(place.toInsertJson(userId), onConflict: 'user_id,label')
        .select()
        .single();
    return SavedPlace.fromJson(response);
  }

  Future<void> deletePlace(String placeId) async {
    await _supabase.from('saved_places').delete().eq('id', placeId);
  }

  Future<void> updatePlace(String placeId, Map<String, dynamic> updates) async {
    await _supabase.from('saved_places').update(updates).eq('id', placeId);
  }
}
