import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

class RoutingService {
  // OSRM public demo server (for development)
  // TODO: Replace with self-hosted gps.tranzfort.com in production
  static const _baseUrl = 'https://router.project-osrm.org';

  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Calculate route between two points using OSRM.
  /// Returns a list of alternate routes (usually 1-3).
  Future<List<RouteModel>> getRoute({
    required LatLng origin,
    required LatLng destination,
    bool alternatives = true,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=true'
      '&annotations=duration,distance'
      '${alternatives ? '&alternatives=true' : ''}',
    );

    final response = await _client.get(url).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw RoutingException('Route request timed out'),
    );

    if (response.statusCode != 200) {
      throw RoutingException('OSRM returned status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final code = data['code'] as String?;
    if (code != 'Ok') {
      throw RoutingException('OSRM error: ${data['message'] ?? code}');
    }

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw RoutingException('No route found');
    }

    return routes.map((r) => _parseRoute(r as Map<String, dynamic>)).toList();
  }

  RouteModel _parseRoute(Map<String, dynamic> routeJson) {
    // Parse polyline from GeoJSON geometry
    final geometry = routeJson['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final polyline = coordinates
        .map((c) {
          final coord = c as List<dynamic>;
          return LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          );
        })
        .toList();

    final distanceM = (routeJson['distance'] as num).toDouble();
    final durationS = (routeJson['duration'] as num).toDouble();

    // Parse steps from legs
    final legs = routeJson['legs'] as List<dynamic>;
    final steps = <NavigationStep>[];
    final roadNames = <String>{};

    for (final leg in legs) {
      final legSteps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>;
      for (final step in legSteps) {
        final s = step as Map<String, dynamic>;
        final maneuver = s['maneuver'] as Map<String, dynamic>;
        final stepGeometry = s['geometry'] as Map<String, dynamic>;
        final stepCoords = stepGeometry['coordinates'] as List<dynamic>;

        final roadName = s['name'] as String? ?? '';
        if (roadName.isNotEmpty && roadName != '') {
          roadNames.add(roadName);
        }

        steps.add(NavigationStep(
          instruction: _buildInstruction(maneuver, roadName),
          maneuverType: maneuver['type'] as String? ?? 'turn',
          modifier: maneuver['modifier'] as String?,
          roadName: roadName.isNotEmpty ? roadName : null,
          distanceKm: (s['distance'] as num).toDouble() / 1000,
          durationSec: (s['duration'] as num).toDouble(),
          geometry: stepCoords
              .map((c) {
                final coord = c as List<dynamic>;
                return LatLng(
                  (coord[1] as num).toDouble(),
                  (coord[0] as num).toDouble(),
                );
              })
              .toList(),
        ));
      }
    }

    // Build via-roads string from major road names (NH-*, SH-*)
    final majorRoads = roadNames
        .where((r) => r.startsWith('NH') || r.startsWith('SH') || r.contains('Highway'))
        .take(3)
        .toList();

    return RouteModel(
      polyline: polyline,
      distanceKm: distanceM / 1000,
      durationMin: durationS / 60,
      steps: steps,
      viaRoads: majorRoads.isNotEmpty ? majorRoads.join(' → ') : null,
    );
  }

  String _buildInstruction(Map<String, dynamic> maneuver, String roadName) {
    final type = maneuver['type'] as String? ?? '';
    final modifier = maneuver['modifier'] as String? ?? '';

    switch (type) {
      case 'turn':
        return 'Turn $modifier${roadName.isNotEmpty ? ' onto $roadName' : ''}';
      case 'new name':
      case 'continue':
        return 'Continue${roadName.isNotEmpty ? ' on $roadName' : ''}';
      case 'merge':
        return 'Merge${roadName.isNotEmpty ? ' onto $roadName' : ''}';
      case 'roundabout':
        final exit = maneuver['exit'] as int?;
        return exit != null
            ? 'Take exit $exit at the roundabout'
            : 'Enter the roundabout';
      case 'arrive':
        return 'You have arrived at your destination';
      case 'depart':
        return 'Start${roadName.isNotEmpty ? ' on $roadName' : ''}';
      default:
        return '$type $modifier'.trim();
    }
  }

  void dispose() {
    _client.close();
  }
}

class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);

  @override
  String toString() => 'RoutingException: $message';
}
