import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/routing_service.dart';
import '../services/saved_places_service.dart';
import '../services/tracking_service.dart';
import '../services/location_suggestions_service.dart';
import '../services/nearby_pois_service.dart';
import '../services/toll_matching_service.dart';
import '../services/trip_costing_service.dart';

final routingServiceProvider = Provider<RoutingService>((ref) {
  final service = RoutingService();
  ref.onDispose(() => service.dispose());
  return service;
});

final trackingServiceProvider = Provider<TrackingService>((ref) {
  final service = TrackingService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});

final savedPlacesServiceProvider = Provider<SavedPlacesService>((ref) {
  return SavedPlacesService(Supabase.instance.client);
});

final locationSuggestionsServiceProvider =
    Provider<LocationSuggestionsService>((ref) {
  return LocationSuggestionsService(Supabase.instance.client);
});

final nearbyPoisServiceProvider = Provider<NearbyPoisService>((ref) {
  return NearbyPoisService(Supabase.instance.client);
});

final tripCostingServiceProvider = Provider<TripCostingService>((ref) {
  return TripCostingService();
});

final tollMatchingServiceProvider = Provider<TollMatchingService>((ref) {
  return TollMatchingService();
});
