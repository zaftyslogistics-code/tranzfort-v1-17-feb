import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A lightweight static route map widget that draws origin → destination
/// as a curved line with dots. No API key required.
///
/// Use this on load cards and load detail screens for a quick visual.
/// Tap to expand into full interactive map (Tier 2).
class StaticRouteMap extends StatelessWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? originLabel;
  final String? destLabel;
  final double height;
  final VoidCallback? onTap;

  const StaticRouteMap({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.originLabel,
    this.destLabel,
    this.height = 120,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDefault, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _RouteMapPainter(
            originLat: originLat,
            originLng: originLng,
            destLat: destLat,
            destLng: destLng,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (originLabel != null)
                  _LocationLabel(
                    label: originLabel!,
                    color: AppColors.success,
                    icon: Icons.circle,
                  ),
                if (destLabel != null)
                  _LocationLabel(
                    label: destLabel!,
                    color: AppColors.error,
                    icon: Icons.location_on,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _LocationLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;

  _RouteMapPainter({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 30.0;
    final usableWidth = size.width - padding * 2;
    final usableHeight = size.height - padding * 2;

    // Map lat/lng to canvas coordinates
    final minLat = math.min(originLat, destLat);
    final maxLat = math.max(originLat, destLat);
    final minLng = math.min(originLng, destLng);
    final maxLng = math.max(originLng, destLng);

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    // Avoid division by zero for same-city routes
    final effectiveLatRange = latRange < 0.01 ? 1.0 : latRange;
    final effectiveLngRange = lngRange < 0.01 ? 1.0 : lngRange;

    Offset toCanvas(double lat, double lng) {
      final x = padding + ((lng - minLng) / effectiveLngRange) * usableWidth;
      // Invert Y because canvas Y goes down but lat goes up
      final y = padding + (1 - (lat - minLat) / effectiveLatRange) * usableHeight;
      return Offset(x, y);
    }

    final origin = toCanvas(originLat, originLng);
    final dest = toCanvas(destLat, destLng);

    // Draw grid lines (subtle)
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E6ED)
      ..strokeWidth = 0.5;

    for (var i = 0; i <= 4; i++) {
      final y = padding + (usableHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      final x = padding + (usableWidth / 4) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw curved route line
    final routePaint = Paint()
      ..color = AppColors.brandTeal
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final midX = (origin.dx + dest.dx) / 2;
    final midY = math.min(origin.dy, dest.dy) - 20;

    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(midX, midY, dest.dx, dest.dy);

    canvas.drawPath(path, routePaint);

    // Draw dashed shadow under route
    final shadowPaint = Paint()
      ..color = AppColors.brandTeal.withValues(alpha: 0.15)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, shadowPaint);

    // Draw origin dot (green)
    canvas.drawCircle(
      origin,
      6,
      Paint()..color = AppColors.success,
    );
    canvas.drawCircle(
      origin,
      3,
      Paint()..color = Colors.white,
    );

    // Draw destination dot (red)
    canvas.drawCircle(
      dest,
      6,
      Paint()..color = AppColors.error,
    );
    canvas.drawCircle(
      dest,
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) {
    return originLat != oldDelegate.originLat ||
        originLng != oldDelegate.originLng ||
        destLat != oldDelegate.destLat ||
        destLng != oldDelegate.destLng;
  }
}
