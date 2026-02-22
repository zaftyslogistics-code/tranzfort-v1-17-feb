import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/map_launcher.dart';

/// Task 6.1: Reusable inline mini-map with OSM tiles, route polyline,
/// origin pin (green) and destination pin (red).
/// 120px height by default, non-interactive. Tap → callback.
/// Long-press → Open in Google Maps.
class RouteMapPreview extends StatelessWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? originLabel;
  final String? destLabel;
  final double height;
  final List<LatLng>? polylinePoints;
  final VoidCallback? onTap;

  const RouteMapPreview({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.originLabel,
    this.destLabel,
    this.height = 120,
    this.polylinePoints,
    this.onTap,
  });

  /// Placeholder for when lat/lng is unavailable.
  static Widget placeholder({double height = 120}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 28, color: AppColors.textTertiary),
            const SizedBox(height: 4),
            Text(
              'Map not available',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  LatLngBounds get _bounds {
    final sw = LatLng(
      originLat < destLat ? originLat : destLat,
      originLng < destLng ? originLng : destLng,
    );
    final ne = LatLng(
      originLat > destLat ? originLat : destLat,
      originLng > destLng ? originLng : destLng,
    );
    return LatLngBounds(sw, ne);
  }

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(originLat, originLng);
    final dest = LatLng(destLat, destLng);

    // Build polyline: use provided points or simple origin→dest
    final routePoints = polylinePoints ?? [origin, dest];

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => MapLauncher.openGoogleMapsRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      ),
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDefault, width: 0.5),
        ),
        child: AbsorbPointer(
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: _bounds,
                padding: const EdgeInsets.all(24),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tranzfort.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: AppColors.brandTeal,
                    strokeWidth: 3.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Origin marker (green)
                  Marker(
                    point: origin,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.circle, size: 8, color: Colors.white),
                    ),
                  ),
                  // Destination marker (red)
                  Marker(
                    point: dest,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
