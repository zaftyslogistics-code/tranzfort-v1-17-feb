import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Utility for launching Google Maps with route directions.
class MapLauncher {
  MapLauncher._();

  /// Opens Google Maps with directions from origin to destination.
  /// Falls back to web URL if native app is not available.
  static Future<void> openGoogleMapsRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final Uri uri;

    if (Platform.isAndroid) {
      // Android: Google Maps intent with waypoints
      uri = Uri.parse(
        'google.navigation:q=$destLat,$destLng&mode=d',
      );
    } else if (Platform.isIOS) {
      // iOS: comgooglemaps scheme
      uri = Uri.parse(
        'comgooglemaps://?saddr=$originLat,$originLng&daddr=$destLat,$destLng&directionsmode=driving',
      );
    } else {
      uri = _webFallbackUri(originLat, originLng, destLat, destLng);
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web
      final webUri = _webFallbackUri(originLat, originLng, destLat, destLng);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Google Maps centered on a single location.
  static Future<void> openGoogleMapsLocation({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final query = label != null ? Uri.encodeComponent(label) : '$lat,$lng';
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Uri _webFallbackUri(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    return Uri.parse(
      'https://www.google.com/maps/dir/$originLat,$originLng/$destLat,$destLng',
    );
  }
}
