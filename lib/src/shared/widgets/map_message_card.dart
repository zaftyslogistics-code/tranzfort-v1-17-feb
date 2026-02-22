import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import 'route_map_preview.dart';

/// Rich map card displayed in chat when a load has lat/lng coordinates.
/// Shows origin → destination, distance, cost estimate, and a tap-to-track action.
///
/// Payload JSON expected:
/// ```json
/// {
///   "origin_city": "Mumbai",
///   "dest_city": "Delhi",
///   "origin_lat": 19.076,
///   "origin_lng": 72.877,
///   "dest_lat": 28.613,
///   "dest_lng": 77.209,
///   "distance_km": 1420.5,
///   "duration_min": 1110,
///   "diesel_cost": 8200,
///   "toll_cost": 2150,
///   "total_cost": 10350,
///   "load_id": "uuid",
///   "material": "Steel",
///   "weight_tonnes": 25
/// }
/// ```
class MapMessageCard extends StatelessWidget {
  final Map<String, dynamic> payload;
  final bool isMine;
  final String viewerRole; // 'supplier' or 'trucker'

  const MapMessageCard({
    super.key,
    required this.payload,
    this.isMine = false,
    this.viewerRole = 'trucker',
  });

  @override
  Widget build(BuildContext context) {
    final originCity = payload['origin_city'] as String? ?? '?';
    final destCity = payload['dest_city'] as String? ?? '?';
    final distanceKm = (payload['distance_km'] as num?)?.toDouble();
    final durationMin = (payload['duration_min'] as num?)?.toDouble();
    final dieselCost = (payload['diesel_cost'] as num?)?.toDouble();
    final tollCost = (payload['toll_cost'] as num?)?.toDouble();
    final totalCost = (payload['total_cost'] as num?)?.toDouble();
    final material = payload['material'] as String?;
    final weightTonnes = (payload['weight_tonnes'] as num?)?.toDouble();
    final originLat = (payload['origin_lat'] as num?)?.toDouble();
    final originLng = (payload['origin_lng'] as num?)?.toDouble();
    final destLat = (payload['dest_lat'] as num?)?.toDouble();
    final destLng = (payload['dest_lng'] as num?)?.toDouble();

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine
            ? AppColors.brandTeal.withValues(alpha: 0.08)
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandTeal.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: route icon + cities
          Row(
            children: [
              const Icon(Icons.route, size: 18, color: AppColors.brandTeal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$originCity → $destCity',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Material + weight
          if (material != null || weightTonnes != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (material != null) material,
                if (weightTonnes != null) '${weightTonnes.toStringAsFixed(0)}T',
              ].join(' | '),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],

          // Distance + duration
          if (distanceKm != null || durationMin != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (distanceKm != null) ...[
                  const Icon(Icons.straighten, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${distanceKm.toStringAsFixed(0)} km',
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                ],
                if (durationMin != null) ...[
                  const Icon(Icons.schedule, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(durationMin),
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ],

          // Cost breakdown
          if (totalCost != null && totalCost > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brandTealLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dieselCost != null && dieselCost > 0) ...[
                    _costItem(Icons.local_gas_station, _formatRupees(dieselCost)),
                    const SizedBox(width: 10),
                  ],
                  if (tollCost != null && tollCost > 0) ...[
                    _costItem(Icons.toll, _formatRupees(tollCost)),
                    const SizedBox(width: 10),
                  ],
                  _costItem(Icons.account_balance_wallet, _formatRupees(totalCost)),
                ],
              ),
            ),
          ],

          // Task 6.4: Inline mini-map
          if (originLat != null && originLng != null && destLat != null && destLng != null) ...[
            const SizedBox(height: 8),
            RouteMapPreview(
              originLat: originLat,
              originLng: originLng,
              destLat: destLat,
              destLng: destLng,
              height: 100,
            ),
          ],

          // Action button: Navigate or Track
          if (originLat != null && destLat != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                onPressed: () {
                  final loadId = payload['load_id'] as String?;
                  // V4-019: Supplier sees live tracking, trucker sees route preview
                  if (viewerRole == 'supplier' && loadId != null) {
                    context.push('/navigation/live-tracking/$loadId', extra: {
                      'originCity': originCity,
                      'destCity': destCity,
                    });
                  } else {
                    context.push(
                      '/navigation/preview'
                      '?originLat=$originLat&originLng=$originLng'
                      '&destLat=$destLat&destLng=$destLng'
                      '&originCity=$originCity&destCity=$destCity',
                    );
                  }
                },
                icon: Icon(
                  viewerRole == 'supplier' ? Icons.gps_fixed : Icons.navigation,
                  size: 16,
                ),
                label: Text(
                  viewerRole == 'supplier' ? 'Track Live' : 'View Route',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandTeal,
                  side: const BorderSide(color: AppColors.brandTeal),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _costItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.brandTeal),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.brandTealDark,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatDuration(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatRupees(double amount) {
    final str = amount.round().toString();
    return '₹${str.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }
}
