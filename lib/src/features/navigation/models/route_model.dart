import 'package:latlong2/latlong.dart';

class RouteModel {
  final List<LatLng> polyline;
  final double distanceKm;
  final double durationMin;
  final List<NavigationStep> steps;
  final String? viaRoads;

  const RouteModel({
    required this.polyline,
    required this.distanceKm,
    required this.durationMin,
    required this.steps,
    this.viaRoads,
  });

  String get distanceText {
    if (distanceKm >= 1) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    return '${(distanceKm * 1000).round()} m';
  }

  String get durationText {
    final hours = durationMin ~/ 60;
    final mins = (durationMin % 60).round();
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  DateTime get eta => DateTime.now().add(Duration(minutes: durationMin.round()));
}

class NavigationStep {
  final String instruction;
  final String maneuverType;
  final String? modifier;
  final String? roadName;
  final double distanceKm;
  final double durationSec;
  final List<LatLng> geometry;

  const NavigationStep({
    required this.instruction,
    required this.maneuverType,
    this.modifier,
    this.roadName,
    required this.distanceKm,
    required this.durationSec,
    required this.geometry,
  });

  String get distanceText {
    if (distanceKm >= 1) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    return '${(distanceKm * 1000).round()} m';
  }

  String get hindiInstruction {
    final dist = distanceText;
    final road = roadName ?? '';
    switch (maneuverType) {
      case 'turn':
        if (modifier == 'left') return '$dist mein baayein mudiye${road.isNotEmpty ? ', $road par' : ''}';
        if (modifier == 'right') return '$dist mein daayein mudiye${road.isNotEmpty ? ', $road par' : ''}';
        if (modifier == 'slight left') return '$dist mein halka baayein lein';
        if (modifier == 'slight right') return '$dist mein halka daayein lein';
        return '$dist mein mudiye';
      case 'new name':
      case 'continue':
        return '${road.isNotEmpty ? '$road par ' : ''}seedha chalte rahiye, $dist tak';
      case 'merge':
        return '${road.isNotEmpty ? '$road par ' : ''}merge karein';
      case 'roundabout':
        return 'Gol chakkar mein aagey badhein';
      case 'arrive':
        return 'Aap apni manzil par pahunch gaye hain';
      case 'depart':
        return 'Shuru karein${road.isNotEmpty ? ', $road par' : ''}';
      default:
        return instruction;
    }
  }
}
